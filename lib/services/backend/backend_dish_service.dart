import 'dart:io';

import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/services/aws/aws_dish_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendDishService {
  BackendDishService()
      : _awsDishService =
            AwsDishService(apiClient: BackendFactory.createAwsDishesApiClient());

  final AwsDishService _awsDishService;

  Future<List<DishModel>> getCookDishes(String cookId) {
    return _awsDishService.getCookDishes(cookId);
  }

  Future<List<DishModel>> getCustomerDishes({int limit = 100}) {
    return _awsDishService.getCustomerDishes(limit: limit);
  }

  Future<void> addDish(DishModel dish, List<File> imageFiles) {
    return _awsDishService.addDish(dish, imageFiles);
  }
}
