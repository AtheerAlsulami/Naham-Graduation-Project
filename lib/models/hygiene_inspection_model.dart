enum HygieneInspectionDecision {
  readyAndClean,
  needsCleanup,
  warningIssued,
  serviceRevoked,
}

enum HygieneInspectionCallStatus {
  pending,
  accepted,
  declined,
  completed,
}

extension HygieneInspectionCallStatusX on HygieneInspectionCallStatus {
  String get key {
    switch (this) {
      case HygieneInspectionCallStatus.pending:
        return 'pending';
      case HygieneInspectionCallStatus.accepted:
        return 'accepted';
      case HygieneInspectionCallStatus.declined:
        return 'declined';
      case HygieneInspectionCallStatus.completed:
        return 'completed';
    }
  }

  static HygieneInspectionCallStatus fromKey(String rawKey) {
    switch (rawKey.trim().toLowerCase()) {
      case 'accepted':
        return HygieneInspectionCallStatus.accepted;
      case 'declined':
        return HygieneInspectionCallStatus.declined;
      case 'completed':
        return HygieneInspectionCallStatus.completed;
      default:
        return HygieneInspectionCallStatus.pending;
    }
  }
}

extension HygieneInspectionDecisionX on HygieneInspectionDecision {
  String get key {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'ready_and_clean';
      case HygieneInspectionDecision.needsCleanup:
        return 'needs_cleanup';
      case HygieneInspectionDecision.warningIssued:
        return 'warning_issued';
      case HygieneInspectionDecision.serviceRevoked:
        return 'service_revoked';
    }
  }

  static HygieneInspectionDecision fromKey(String rawKey) {
    switch (rawKey.trim().toLowerCase()) {
      case 'ready_and_clean':
        return HygieneInspectionDecision.readyAndClean;
      case 'needs_cleanup':
        return HygieneInspectionDecision.needsCleanup;
      case 'warning_issued':
        return HygieneInspectionDecision.warningIssued;
      case 'service_revoked':
        return HygieneInspectionDecision.serviceRevoked;
      default:
        return HygieneInspectionDecision.warningIssued;
    }
  }

  String get adminListLabel {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'Compliant';
      case HygieneInspectionDecision.needsCleanup:
        return 'Needs Cleanup';
      case HygieneInspectionDecision.warningIssued:
        return 'Warning Issued';
      case HygieneInspectionDecision.serviceRevoked:
        return 'Eligibility Revoked';
    }
  }

  String get popupLabel {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'Ready & Clean';
      case HygieneInspectionDecision.needsCleanup:
        return 'Needs Cleanup';
      case HygieneInspectionDecision.warningIssued:
        return 'Issue Warning';
      case HygieneInspectionDecision.serviceRevoked:
        return 'Revoke Eligibility';
    }
  }

  String get popupHint {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'Kitchen and cook are fully ready for service.';
      case HygieneInspectionDecision.needsCleanup:
        return 'Minor issues found. follow-up inspection required.';
      case HygieneInspectionDecision.warningIssued:
        return 'Official warning recorded for this cook.';
      case HygieneInspectionDecision.serviceRevoked:
        return 'Cook is blocked from providing service.';
    }
  }

  bool get isCompliant => this == HygieneInspectionDecision.readyAndClean;

  String get accountStatusValue {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'active';
      case HygieneInspectionDecision.needsCleanup:
        return 'warning';
      case HygieneInspectionDecision.warningIssued:
        return 'warning';
      case HygieneInspectionDecision.serviceRevoked:
        return 'suspended';
    }
  }

  String get cookStatusValue {
    switch (this) {
      case HygieneInspectionDecision.readyAndClean:
        return 'approved';
      case HygieneInspectionDecision.needsCleanup:
        return 'pending_verification';
      case HygieneInspectionDecision.warningIssued:
        return 'frozen';
      case HygieneInspectionDecision.serviceRevoked:
        return 'blocked';
    }
  }
}

class HygieneInspectionRecord {
  const HygieneInspectionRecord({
    required this.id,
    required this.cookId,
    required this.cookName,
    required this.decision,
    required this.inspectedAt,
    required this.callDurationSeconds,
    this.adminId,
    this.adminName,
    this.note = '',
  });

  final String id;
  final String cookId;
  final String cookName;
  final HygieneInspectionDecision decision;
  final DateTime inspectedAt;
  final int callDurationSeconds;
  final String? adminId;
  final String? adminName;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cookId': cookId,
      'cookName': cookName,
      'decision': decision.key,
      'inspectedAt': inspectedAt.toIso8601String(),
      'callDurationSeconds': callDurationSeconds,
      'adminId': adminId,
      'adminName': adminName,
      'note': note,
    };
  }

  factory HygieneInspectionRecord.fromMap(Map<String, dynamic> map) {
    return HygieneInspectionRecord(
      id: (map['id'] ?? '').toString(),
      cookId: (map['cookId'] ?? '').toString(),
      cookName: (map['cookName'] ?? '').toString(),
      decision: HygieneInspectionDecisionX.fromKey(
          (map['decision'] ?? '').toString()),
      inspectedAt: DateTime.tryParse((map['inspectedAt'] ?? '').toString()) ??
          DateTime.now(),
      callDurationSeconds: _readInt(map['callDurationSeconds']),
      adminId: _readNullableString(map['adminId']),
      adminName: _readNullableString(map['adminName']),
      note: (map['note'] ?? '').toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class HygieneInspectionCallRequest {
  const HygieneInspectionCallRequest({
    required this.id,
    required this.cookId,
    required this.cookName,
    required this.adminId,
    required this.adminName,
    required this.requestedAt,
    required this.status,
    this.respondedAt,
  });

  final String id;
  final String cookId;
  final String cookName;
  final String adminId;
  final String adminName;
  final DateTime requestedAt;
  final HygieneInspectionCallStatus status;
  final DateTime? respondedAt;

  HygieneInspectionCallRequest copyWith({
    String? id,
    String? cookId,
    String? cookName,
    String? adminId,
    String? adminName,
    DateTime? requestedAt,
    HygieneInspectionCallStatus? status,
    DateTime? respondedAt,
  }) {
    return HygieneInspectionCallRequest(
      id: id ?? this.id,
      cookId: cookId ?? this.cookId,
      cookName: cookName ?? this.cookName,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cookId': cookId,
      'cookName': cookName,
      'adminId': adminId,
      'adminName': adminName,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.key,
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory HygieneInspectionCallRequest.fromMap(Map<String, dynamic> map) {
    return HygieneInspectionCallRequest(
      id: (map['id'] ?? '').toString(),
      cookId: (map['cookId'] ?? '').toString(),
      cookName: (map['cookName'] ?? '').toString(),
      adminId: (map['adminId'] ?? '').toString(),
      adminName: (map['adminName'] ?? '').toString(),
      requestedAt: DateTime.tryParse((map['requestedAt'] ?? '').toString()) ??
          DateTime.now(),
      status: HygieneInspectionCallStatusX.fromKey(
        (map['status'] ?? '').toString(),
      ),
      respondedAt: DateTime.tryParse((map['respondedAt'] ?? '').toString()),
    );
  }
}

class HygieneCookProfile {
  const HygieneCookProfile({
    required this.id,
    required this.name,
    required this.accountStatus,
    required this.cookStatus,
    this.rating = 0,
    this.totalOrders = 0,
    this.isOnline,
  });

  final String id;
  final String name;
  final String accountStatus;
  final String cookStatus;
  final double rating;
  final int totalOrders;
  final bool? isOnline;

  HygieneCookProfile copyWith({
    String? id,
    String? name,
    String? accountStatus,
    String? cookStatus,
    double? rating,
    int? totalOrders,
    bool? isOnline,
  }) {
    return HygieneCookProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      accountStatus: accountStatus ?? this.accountStatus,
      cookStatus: cookStatus ?? this.cookStatus,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
