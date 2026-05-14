import 'package:flutter/material.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/backend/backend_cook_service.dart';

class CookProvider extends ChangeNotifier {
  static const Duration _cacheWindow = Duration(seconds: 90);

  final BackendCookService _cookService;

  CookProvider({BackendCookService? cookService})
      : _cookService = cookService ?? BackendCookService();

  List<UserModel> _cooks = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadedAt;

  List<UserModel> get cooks => _cooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCooks({bool force = false}) async {
    if (_isLoading) {
      return;
    }

    final recentlyLoaded = _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _cacheWindow;
    if (!force && _cooks.isNotEmpty && recentlyLoaded) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cooks = await _cookService.getAvailableCooks();
      _cooks = [...cooks]..sort(
          (a, b) => b.currentMonthOrders.compareTo(a.currentMonthOrders),
        );
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
      _cooks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
