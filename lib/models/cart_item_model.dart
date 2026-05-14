import 'package:naham_app/models/dish_model.dart';

class CartItemModel {
  final DishModel dish;
  int quantity;
  final String? specialInstructions;

  CartItemModel({
    required this.dish,
    required this.quantity,
    this.specialInstructions,
  });

  double get totalPrice => dish.price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'dish': dish.toMap(),
      'quantity': quantity,
      'specialInstructions': specialInstructions,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      dish: DishModel.fromMap(map['dish']),
      quantity: map['quantity']?.toInt() ?? 0,
      specialInstructions: map['specialInstructions'],
    );
  }
}
