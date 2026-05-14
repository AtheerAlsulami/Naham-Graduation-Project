import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/services/backend/backend_dish_service.dart';

class DishProvider extends ChangeNotifier {
  static const Duration _cookDishesCacheWindow = Duration(seconds: 90);

  BackendDishService? _dishService;

  BackendDishService get _service => _dishService ??= BackendDishService();

  List<DishModel> _cookDishes = [];
  List<DishModel> _customerDishes = [];
  int _loadedCustomerDishesLimit = 0;
  String _loadedCookDishesCookId = '';
  DateTime? _lastCookDishesLoadedAt;
  String? _error; // Added error tracking

  bool _isLoadingCookDishes = false;
  bool _isLoadingCustomerDishes = false;
  bool _isAddingDish = false;

  List<DishModel> get cookDishes => _cookDishes;
  List<DishModel> get customerDishes => _customerDishes;
  String? get error => _error;

  bool get isLoadingCookDishes => _isLoadingCookDishes;
  bool get isLoadingCustomerDishes => _isLoadingCustomerDishes;
  bool get isAddingDish => _isAddingDish;

  // Load dishes for a specific cook
  Future<void> loadCookDishes(String cookId, {bool force = false}) async {
    final normalizedCookId = cookId.trim();
    if (normalizedCookId.isEmpty || _isLoadingCookDishes) {
      return;
    }

    final recentlyLoaded = _lastCookDishesLoadedAt != null &&
        DateTime.now().difference(_lastCookDishesLoadedAt!) <
            _cookDishesCacheWindow;
    if (!force &&
        _cookDishes.isNotEmpty &&
        _loadedCookDishesCookId == normalizedCookId &&
        recentlyLoaded) {
      return;
    }

    _isLoadingCookDishes = true;
    notifyListeners();

    try {
      _cookDishes = await _service.getCookDishes(normalizedCookId);
      _loadedCookDishesCookId = normalizedCookId;
      _lastCookDishesLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('Failed to load cook dishes: $e');
    } finally {
      _isLoadingCookDishes = false;
      notifyListeners();
    }
  }

  // Load dishes for customers
  Future<void> loadCustomerDishes({int limit = 100, bool force = false}) async {
    if (_isLoadingCustomerDishes) {
      return;
    }

    if (!force &&
        _customerDishes.isNotEmpty &&
        _loadedCustomerDishesLimit >= limit) {
      return;
    }

    _isLoadingCustomerDishes = true;
    _error = null;
    notifyListeners();

    try {
      _customerDishes = await _service.getCustomerDishes(limit: limit);
      _loadedCustomerDishesLimit = limit;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load customer dishes: $e');
    } finally {
      _isLoadingCustomerDishes = false;
      notifyListeners();
    }
  }

  // Add a new dish
  Future<String?> addDish(DishModel dish, List<File> imageFiles) async {
    _isAddingDish = true;
    notifyListeners();

    try {
      await _service.addDish(dish, imageFiles);
      // Force reload to pick up the backend-assigned image URL.
      await loadCookDishes(dish.cookId, force: true);
      await loadCustomerDishes(limit: 250, force: true);
      return null; // Success
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to add dish: $errorMsg');
      return errorMsg;
    } finally {
      _isAddingDish = false;
      notifyListeners();
    }
  }

  DishModel? findDishById(String id) {
    for (final dish in _customerDishes) {
      if (dish.id == id) return dish;
    }
    for (final dish in _cookDishes) {
      if (dish.id == id) return dish;
    }
    return null;
  }
}
