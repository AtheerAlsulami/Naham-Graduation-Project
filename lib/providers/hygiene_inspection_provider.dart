import 'package:flutter/material.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';
import 'package:naham_app/services/backend/backend_admin_user_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';
import 'package:naham_app/services/aws/aws_hygiene_service.dart';
import 'package:naham_app/services/hygiene_inspection_storage_service.dart';
import 'dart:async';

class HygieneInspectionProvider extends ChangeNotifier {
  HygieneInspectionProvider({
    BackendAdminUserService? adminUserService,
    HygieneInspectionStorageService? storageService,
    AwsHygieneService? awsHygieneService,
  })  : _adminUserService = adminUserService ?? BackendAdminUserService(),
        _storageService = storageService ?? HygieneInspectionStorageService(),
        _awsHygieneService =
            awsHygieneService ?? BackendFactory.createAwsHygieneService();

  final BackendAdminUserService _adminUserService;
  final HygieneInspectionStorageService _storageService;
  final AwsHygieneService _awsHygieneService;

  Timer? _callPollingTimer;
  String? _boundCookId;

  bool _isLoading = false;
  bool _isReady = false;
  String? _errorMessage;
  List<HygieneInspectionRecord> _records = <HygieneInspectionRecord>[];
  List<HygieneCookProfile> _cooks = <HygieneCookProfile>[];
  List<HygieneInspectionCallRequest> _callRequests =
      <HygieneInspectionCallRequest>[];
  final Set<String> _syncingCookIds = <String>{};

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;
  bool get hasRecords => _records.isNotEmpty;
  bool get hasCooks => _cooks.isNotEmpty;
  List<HygieneInspectionRecord> get records => List.unmodifiable(_records);
  List<HygieneCookProfile> get cooks => List.unmodifiable(_cooks);
  List<HygieneInspectionCallRequest> get callRequests =>
      List.unmodifiable(_callRequests);

  List<HygieneInspectionRecord> get compliantRecords {
    final latest = _latestRecordsPerCook();
    return latest.where((item) => item.decision.isCompliant).toList();
  }

  List<HygieneInspectionRecord> get nonCompliantRecords {
    final latest = _latestRecordsPerCook();
    return latest.where((item) => !item.decision.isCompliant).toList();
  }

  Future<void> initialize({bool force = false}) async {
    if (_isLoading) return;
    if (_isReady && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load from AWS if cook is bound
      if (_boundCookId != null) {
        _records = await _awsHygieneService.getRecords(cookId: _boundCookId);
        _callRequests =
            await _awsHygieneService.getPendingCallRequests(_boundCookId!);
      } else {
        // Fallback to local storage for general list or when no cook is bound
        final loadedRecords = await _storageService.loadRecords();
        final cleanedRecords = _removeSeedRecords(loadedRecords);
        _records = _sortRecords(cleanedRecords);
        _callRequests = _sortCallRequests(
          await _storageService.loadCallRequests(),
        );
        // Persist cleanup once if old seeded demo records were present.
        if (loadedRecords.length != cleanedRecords.length) {
          await _storageService.saveRecords(_records);
        }
      }

      final users = await _adminUserService.listUsers(
        role: AppConstants.roleCook,
        limit: 500,
      );
      if (users.isEmpty) {
        _cooks = _buildFallbackCooksFromHistory();
      } else {
        _cooks = users.map(_toCookProfile).toList();
      }
      _applyLatestDecisionOnCooks();
      _isReady = true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      if (_cooks.isEmpty) {
        _cooks = _buildFallbackCooksFromHistory();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCooks() async {
    if (_isLoading) return;
    await initialize(force: true);
  }

  Future<void> registerInspection({
    required HygieneCookProfile cook,
    required HygieneInspectionDecision decision,
    required int callDurationSeconds,
    required AuthProvider authProvider,
    String note = '',
  }) async {
    final now = DateTime.now();
    final adminId = authProvider.currentUser?.id;
    final adminName = authProvider.currentUser?.name;

    final record = HygieneInspectionRecord(
      id: 'inspection_${now.microsecondsSinceEpoch}_${cook.id}',
      cookId: cook.id,
      cookName: cook.name,
      decision: decision,
      inspectedAt: now,
      callDurationSeconds: callDurationSeconds,
      adminId: adminId,
      adminName: adminName,
      note: note,
    );

    _records = _sortRecords(<HygieneInspectionRecord>[record, ..._records]);
    _upsertCookDecision(cookId: cook.id, decision: decision);
    notifyListeners();

    // Sync to AWS
    await _awsHygieneService.saveRecord(record);
    await _storageService.saveRecords(_records);
    await _syncCookStatusToBackend(cook.id, decision);
  }

  Future<HygieneInspectionCallRequest> createSurpriseCallRequest({
    required HygieneCookProfile cook,
    required AuthProvider authProvider,
  }) async {
    final now = DateTime.now();
    final adminId = authProvider.currentUser?.id ?? 'admin_unknown';
    final adminName = authProvider.currentUser?.name.trim().isNotEmpty == true
        ? authProvider.currentUser!.name.trim()
        : 'System Admin';

    final existingIndex = _callRequests.indexWhere(
      (item) =>
          item.cookId == cook.id &&
          item.status == HygieneInspectionCallStatus.pending,
    );

    final request = HygieneInspectionCallRequest(
      id: 'call_${now.microsecondsSinceEpoch}_${cook.id}',
      cookId: cook.id,
      cookName: cook.name,
      adminId: adminId,
      adminName: adminName,
      requestedAt: now,
      status: HygieneInspectionCallStatus.pending,
    );

    if (existingIndex != -1) {
      _callRequests[existingIndex] = request;
    } else {
      _callRequests = <HygieneInspectionCallRequest>[
        request,
        ..._callRequests,
      ];
    }
    _callRequests = _sortCallRequests(_callRequests);
    notifyListeners();

    // Sync to AWS
    final synced = await _awsHygieneService.createCallRequest(request);

    await _storageService.saveCallRequests(_callRequests);
    return synced;
  }

  HygieneInspectionCallRequest? pendingRequestForCook({
    required String cookId,
  }) {
    final normalizedCookId = cookId.trim();
    for (final item in _callRequests) {
      if (item.status == HygieneInspectionCallStatus.pending &&
          item.cookId == normalizedCookId) {
        return item;
      }
    }
    return null;
  }

  Future<void> markCallRequestAccepted(String requestId) async {
    final index = _callRequests.indexWhere((item) => item.id == requestId);
    if (index == -1) return;
    final updated = _callRequests[index].copyWith(
      status: HygieneInspectionCallStatus.accepted,
      respondedAt: DateTime.now(),
    );
    _callRequests[index] = updated;
    _callRequests = _sortCallRequests(_callRequests);
    notifyListeners();

    await _awsHygieneService.updateCallRequestStatus(requestId, 'accepted');
    await _storageService.saveCallRequests(_callRequests);
  }

  Future<void> markCallRequestCompleted(String requestId) async {
    final index = _callRequests.indexWhere((item) => item.id == requestId);
    if (index == -1) return;
    final updated = _callRequests[index].copyWith(
      status: HygieneInspectionCallStatus.completed,
      respondedAt: DateTime.now(),
    );
    _callRequests[index] = updated;
    _callRequests = _sortCallRequests(_callRequests);
    notifyListeners();

    await _awsHygieneService.updateCallRequestStatus(requestId, 'completed');
    await _storageService.saveCallRequests(_callRequests);
  }

  Future<void> markCallRequestDeclined(
    String requestId, {
    String note = '',
  }) async {
    final requestIndex =
        _callRequests.indexWhere((item) => item.id == requestId);
    if (requestIndex == -1) return;

    final request = _callRequests[requestIndex];
    _callRequests[requestIndex] = request.copyWith(
      status: HygieneInspectionCallStatus.declined,
      respondedAt: DateTime.now(),
    );

    final cook = findCookById(request.cookId) ??
        HygieneCookProfile(
          id: request.cookId,
          name: request.cookName,
          accountStatus: 'active',
          cookStatus: 'approved',
        );
    final now = DateTime.now();
    final declineNote = note.trim().isEmpty
        ? 'Cook declined the surprise live inspection request.'
        : note.trim();

    final record = HygieneInspectionRecord(
      id: 'inspection_declined_${now.microsecondsSinceEpoch}_${request.cookId}',
      cookId: cook.id,
      cookName: cook.name,
      decision: HygieneInspectionDecision.warningIssued,
      inspectedAt: now,
      callDurationSeconds: 0,
      adminId: request.adminId,
      adminName: request.adminName,
      note: declineNote,
    );

    _records = _sortRecords(<HygieneInspectionRecord>[record, ..._records]);
    _upsertCookDecision(
      cookId: cook.id,
      decision: HygieneInspectionDecision.warningIssued,
    );
    _callRequests = _sortCallRequests(_callRequests);
    notifyListeners();

    await _awsHygieneService.updateCallRequestStatus(requestId, 'declined');
    await _awsHygieneService.saveRecord(record);

    await _storageService.saveRecords(_records);
    await _storageService.saveCallRequests(_callRequests);
    await _syncCookStatusToBackend(
      cook.id,
      HygieneInspectionDecision.warningIssued,
    );
  }

  void bindCook(String? cookId) {
    if (_boundCookId == cookId) return;
    _boundCookId = cookId;
    _stopCallPolling();
    if (cookId != null) {
      _startCallPolling();
      initialize(force: true);
    }
  }

  void _startCallPolling() {
    _callPollingTimer?.cancel();
    _callPollingTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_boundCookId == null) return;
      try {
        final pending =
            await _awsHygieneService.getPendingCallRequests(_boundCookId!);
        if (pending.isNotEmpty) {
          _callRequests = _sortCallRequests(pending);
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void _stopCallPolling() {
    _callPollingTimer?.cancel();
    _callPollingTimer = null;
  }

  @override
  void dispose() {
    _stopCallPolling();
    super.dispose();
  }

  HygieneCookProfile? findCookById(String cookId) {
    for (final cook in _cooks) {
      if (cook.id == cookId) {
        return cook;
      }
    }
    return null;
  }

  List<HygieneInspectionRecord> recordsForCook({
    required String cookId,
    required String cookName,
  }) {
    final normalizedName = cookName.trim().toLowerCase();
    final filtered = _records.where((item) {
      if (item.cookId == cookId) return true;
      return item.cookName.trim().toLowerCase() == normalizedName;
    }).toList();
    return _sortRecords(filtered);
  }

  Future<void> _syncCookStatusToBackend(
    String cookId,
    HygieneInspectionDecision decision,
  ) async {
    if (cookId.trim().isEmpty || _syncingCookIds.contains(cookId)) {
      return;
    }

    _syncingCookIds.add(cookId);
    try {
      final updated = await _adminUserService.updateUserStatus(
        id: cookId,
        status: decision.accountStatusValue,
        cookStatus: decision.cookStatusValue,
      );
      if (updated != null) {
        final index = _cooks.indexWhere((item) => item.id == cookId);
        if (index != -1) {
          _cooks[index] = _toCookProfile(updated);
          _applyLatestDecisionOnSingleCook(cookId);
          notifyListeners();
        }
      }
    } catch (_) {
      // Status sync is best effort. UI state remains usable with local records.
    } finally {
      _syncingCookIds.remove(cookId);
    }
  }

  void _applyLatestDecisionOnCooks() {
    for (final cook in _cooks) {
      _applyLatestDecisionOnSingleCook(cook.id, notify: false);
    }
  }

  void _applyLatestDecisionOnSingleCook(
    String cookId, {
    bool notify = false,
  }) {
    final index = _cooks.indexWhere((item) => item.id == cookId);
    if (index == -1) return;

    final latest =
        _latestRecordForCook(cookId: cookId, cookName: _cooks[index].name);
    if (latest == null) return;

    _cooks[index] = _cooks[index].copyWith(
      accountStatus: latest.decision.accountStatusValue,
      cookStatus: latest.decision.cookStatusValue,
    );
    if (notify) {
      notifyListeners();
    }
  }

  HygieneInspectionRecord? _latestRecordForCook({
    required String cookId,
    required String cookName,
  }) {
    for (final record in _records) {
      if (record.cookId == cookId) {
        return record;
      }
      if (record.cookName.trim().toLowerCase() ==
          cookName.trim().toLowerCase()) {
        return record;
      }
    }
    return null;
  }

  void _upsertCookDecision({
    required String cookId,
    required HygieneInspectionDecision decision,
  }) {
    final index = _cooks.indexWhere((item) => item.id == cookId);
    if (index == -1) return;
    final updated = _cooks[index].copyWith(
      accountStatus: decision.accountStatusValue,
      cookStatus: decision.cookStatusValue,
    );
    _cooks[index] = updated;
  }

  HygieneCookProfile _toCookProfile(AdminUserRecord record) {
    final cookStatus = _normalized(record.cookStatus);
    final accountStatus = _normalized(record.status);

    return HygieneCookProfile(
      id: record.id,
      name: record.name,
      accountStatus: accountStatus.isEmpty ? 'active' : accountStatus,
      cookStatus: cookStatus.isEmpty ? 'approved' : cookStatus,
      rating: record.rating,
      totalOrders: record.orders,
      isOnline: record.isOnline,
    );
  }

  List<HygieneCookProfile> _buildFallbackCooksFromHistory() {
    final map = <String, HygieneCookProfile>{};
    for (final record in _records) {
      final key = record.cookId.trim().isEmpty
          ? record.cookName.trim().toLowerCase()
          : record.cookId;
      if (key.isEmpty) continue;
      map[key] = HygieneCookProfile(
        id: record.cookId.trim().isEmpty ? key : record.cookId,
        name: record.cookName,
        accountStatus: record.decision.accountStatusValue,
        cookStatus: record.decision.cookStatusValue,
      );
    }
    return map.values.toList();
  }

  List<HygieneInspectionRecord> _sortRecords(
    List<HygieneInspectionRecord> input,
  ) {
    final records = List<HygieneInspectionRecord>.from(input);
    records.sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    return records;
  }

  List<HygieneInspectionCallRequest> _sortCallRequests(
    List<HygieneInspectionCallRequest> input,
  ) {
    final requests = List<HygieneInspectionCallRequest>.from(input);
    requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return requests;
  }

  List<HygieneInspectionRecord> _latestRecordsPerCook() {
    final latestByCook = <String, HygieneInspectionRecord>{};
    for (final record in _records) {
      final key = _cookRecordKey(record.cookId, record.cookName);
      if (key.isEmpty) continue;
      latestByCook.putIfAbsent(key, () => record);
    }
    return _sortRecords(latestByCook.values.toList());
  }

  List<HygieneInspectionRecord> _removeSeedRecords(
    List<HygieneInspectionRecord> input,
  ) {
    return input.where((item) => !item.id.startsWith('seed_')).toList();
  }

  String _cookRecordKey(String cookId, String cookName) {
    final normalizedId = cookId.trim();
    if (normalizedId.isNotEmpty) {
      return normalizedId;
    }
    return cookName.trim().toLowerCase();
  }

  String _normalized(String? value) => (value ?? '').trim().toLowerCase();
}
