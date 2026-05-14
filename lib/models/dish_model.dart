class DishModel {
  final String id;
  final String cookId;
  final String cookName;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final int currentMonthOrders;
  final int totalOrders;
  final String categoryId;
  final List<String> ingredients;
  final bool isAvailable;
  final int preparationTimeMin;
  final int preparationTimeMax;
  final DateTime? createdAt;

  const DishModel({
    required this.id,
    required this.cookId,
    required this.cookName,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.currentMonthOrders = 0,
    this.totalOrders = 0,
    required this.categoryId,
    this.ingredients = const [],
    this.isAvailable = true,
    this.preparationTimeMin = 30,
    this.preparationTimeMax = 60,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cookId': cookId,
      'cookName': cookName,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'currentMonthOrders': currentMonthOrders,
      'totalOrders': totalOrders,
      'categoryId': categoryId,
      'ingredients': ingredients,
      'isAvailable': isAvailable,
      'preparationTimeMin': preparationTimeMin,
      'preparationTimeMax': preparationTimeMax,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Resolves the dish image URL from multiple possible field names the backend
  /// might return. Checks direct URL fields first, then array fields, and
  /// finally falls back to reconstructing from the S3 object key.
  static String _resolveImageUrl(Map<String, dynamic> map) {
    // 1. Try common direct-URL field names.
    for (final key in [
      'imageUrl',
      'image_url',
      'image',
      'photo',
      'photoUrl',
      'photo_url',
      'fileUrl',
      'file_url',
    ]) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    // 2. Try array fields (photos / images).
    for (final key in ['photos', 'images']) {
      final value = map[key];
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
        if (first is Map) {
          final nested =
              (first['url'] ?? first['fileUrl'] ?? first['imageUrl'] ?? '')
                  .toString()
                  .trim();
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }
    }

    // 3. Reconstruct from S3 object key if available.
    for (final key in ['imageKey', 'image_key', 'key']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        final objectKey = value.trim();
        // If the key already looks like a full URL, use it directly.
        if (objectKey.startsWith('http')) {
          return objectKey;
        }
        // Otherwise skip bare keys – the backend must provide a resolvable URL.
      }
    }

    return '';
  }

  factory DishModel.fromMap(Map<String, dynamic> map) {
    return DishModel(
      id: (map['id'] ?? '').toString().trim(),
      cookId: (map['cookId'] ?? '').toString().trim(),
      cookName: (map['cookName'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString(),
      price: _parseToDouble(map['price'], 0.0),
      imageUrl: _resolveImageUrl(map),
      rating: _parseToDouble(map['rating'], 0.0),
      reviewsCount: _parseToInt(map['reviewsCount'], 0),
      currentMonthOrders: _parseToInt(map['currentMonthOrders'], 0),
      totalOrders: _parseToInt(map['totalOrders'], 0),
      categoryId: (map['categoryId'] ?? '').toString().trim(),
      ingredients: List<String>.from(map['ingredients'] ?? []),
      isAvailable: map['isAvailable'] == null
          ? true
          : (map['isAvailable'] == true || map['isAvailable'] == 'true'),
      preparationTimeMin: _parseToInt(map['preparationTimeMin'], 30),
      preparationTimeMax: _parseToInt(map['preparationTimeMax'], 60),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  static double _parseToDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _parseToInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

// ─── Mock Data ───
class MockData {
  static List<DishModel> get allDishes => [];

  static DishModel? dishById(String id) {
    return null;
  }

  static List<DishModel> dishesForCategory(String categoryId) {
    return [];
  }

  static final List<DishModel> activeDishes = [];
  static final List<DishModel> categoryDishes = [];
  static final List<Map<String, dynamic>> topCooks = [];
}
