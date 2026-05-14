import 'package:flutter/material.dart';
import 'package:naham_app/models/cart_item_model.dart';
import 'package:naham_app/models/dish_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _currentCookId;

  List<CartItemModel> get items => _items;
  String? get currentCookId => _currentCookId;

  // ─── Computed Getters ───
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee =>
      _items.isEmpty ? 0 : 15.0; // Mock fixed delivery fee

  double get total => subtotal + deliveryFee;

  // ─── Actions ───

  void addItem(DishModel dish, int quantity, {String? specialInstructions}) {
    // If cart is empty, set current cook
    if (_items.isEmpty) {
      _currentCookId = dish.cookId;
    } else if (_currentCookId != dish.cookId) {
      // Must clear cart or handle multiple cooks (Normally 1 cook per order)
      throw Exception(
          'You cannot add dishes from different cooks to the same order.');
    }

    final index = _items.indexWhere((item) => item.dish.id == dish.id);

    if (index >= 0) {
      // Item already in cart, update quantity
      _items[index].quantity += quantity;
      // Append instructions if new ones provided
      if (specialInstructions != null && specialInstructions.isNotEmpty) {
        // Simple mock behavior: overwrite or append. We will just ignore for now as it's complex to merge.
      }
    } else {
      // Add new item
      _items.add(CartItemModel(
        dish: dish,
        quantity: quantity,
        specialInstructions: specialInstructions,
      ));
    }
    notifyListeners();
  }

  void removeItem(String dishId) {
    _items.removeWhere((item) => item.dish.id == dishId);
    if (_items.isEmpty) {
      _currentCookId = null;
    }
    notifyListeners();
  }

  void updateQuantity(String dishId, int quantity) {
    final index = _items.indexWhere((item) => item.dish.id == dishId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(dishId);
      } else {
        _items[index].quantity = quantity;
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _items.clear();
    _currentCookId = null;
    notifyListeners();
  }
}
