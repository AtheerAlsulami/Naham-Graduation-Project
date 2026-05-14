import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsDishService {
  AwsDishService({required this.apiClient});

  final AwsApiClient apiClient;

  // Carries both public file URL and the S3 object key returned by backend.
  // Storing the key lets Lambda re-sign images even when public URL domain changes.
  static const String _imageKeyField = 'imageKey';

  Map<String, dynamic> _asJsonMap(
    dynamic value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw Exception('Invalid $context: empty string.');
      }
      final decoded = jsonDecode(trimmed);
      return _asJsonMap(decoded, context: '$context (decoded from string)');
    }
    throw Exception('Invalid $context. Expected JSON object.');
  }

  dynamic _decodeResponsePayload(String bodyString) {
    final decoded = jsonDecode(bodyString);
    if (decoded is List && decoded.length == 1 && decoded.first is Map) {
      return decoded.first;
    }
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body') &&
        !decoded.containsKey('items') &&
        !decoded.containsKey('dishes') &&
        !decoded.containsKey('uploadUrl')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  List<Map<String, dynamic>> _extractDishList(dynamic payload) {
    if (payload is List) {
      if (payload.length == 1 && payload.first is Map) {
        final wrapper = payload.first;
        if (wrapper is Map) {
          final wrappedItems =
              wrapper['items'] ?? wrapper['dishes'] ?? wrapper['data'];
          if (wrappedItems is List) {
            return wrappedItems
                .whereType<Map>()
                .map((item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)))
                .toList();
          }
        }
      }
      return payload
          .whereType<Map>()
          .map((item) =>
              item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }

    final body = _asJsonMap(payload, context: 'dishes response');
    final candidates =
        body['items'] ?? body['dishes'] ?? body['data'] ?? const [];
    if (candidates is! List) {
      return const [];
    }
    return candidates
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  String _detectImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  /// Logs the image-related keys from the first dish map to help diagnose
  /// which field name the backend uses for the image URL.
  void _logDishImageFields(List<Map<String, dynamic>> dishes, String caller) {
    if (dishes.isEmpty) return;
    final first = dishes.first;
    const imageKeys = [
      'imageUrl',
      'image_url',
      'image',
      'photo',
      'photoUrl',
      'photo_url',
      'fileUrl',
      'file_url',
      'photos',
      'images',
      'imageKey',
      'image_key',
      'key',
    ];
    final found = <String, dynamic>{};
    for (final k in imageKeys) {
      if (first.containsKey(k)) {
        found[k] = first[k];
      }
    }
    debugPrint('[AwsDishService][$caller] dish keys: ${first.keys.toList()}');
    debugPrint('[AwsDishService][$caller] image fields: $found');
  }

  Future<List<DishModel>> getCookDishes(String cookId) async {
    final response = await apiClient.get(
      '/dishes',
      queryParameters: {
        'cookId': cookId,
        'sort': 'orders_current_month',
        'limit': '500',
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final dishes = _extractDishList(payload);
    _logDishImageFields(dishes, 'getCookDishes');
    return dishes.map(DishModel.fromMap).toList();
  }

  Future<List<DishModel>> getCustomerDishes({int limit = 10}) async {
    final response = await apiClient.get(
      '/dishes',
      queryParameters: {
        'onlyAvailable': 'true',
        'sort': 'newest',
        'limit': '$limit',
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final dishes = _extractDishList(payload);
    _logDishImageFields(dishes, 'getCustomerDishes');
    return dishes.map(DishModel.fromMap).toList();
  }

  Future<Map<String, String>> uploadImage(File imageFile, String dishId) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    final fileName = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final contentType = _detectImageContentType(fileName);

    final response = await apiClient.post(
      '/dishes/upload-url',
      body: {
        'dishId': dishId,
        'fileName': fileName,
        'contentType': contentType,
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'dish upload-url response');

    final uploadUrl = (body['uploadUrl'] ?? '').toString();
    final fileUrl = (body['fileUrl'] ?? '').toString();
    final imageKey = (body['key'] ?? '').toString().trim();
    if (uploadUrl.isEmpty || fileUrl.isEmpty) {
      throw Exception(
        'Invalid upload-url response. Missing uploadUrl or fileUrl.',
      );
    }

    final rawHeaders = body['headers'];
    final Map<String, String> uploadHeaders = {
      'Content-Type': contentType,
    };
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        uploadHeaders[entry.key.toString()] = entry.value.toString();
      }
    }

    final bytes = await imageFile.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: uploadHeaders,
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception(
        'Image upload failed (${uploadResponse.statusCode}). ${uploadResponse.body}',
      );
    }

    return {
      'fileUrl': fileUrl,
      _imageKeyField: imageKey,
    };
  }

  Future<void> addDish(DishModel dish, List<File> imageFiles) async {
    final uploadedImages = <Map<String, String>>[];

    for (final imageFile in imageFiles) {
      final uploaded = await uploadImage(imageFile, dish.id);
      uploadedImages.add(uploaded);
    }

    final primaryImageUrl = uploadedImages.isNotEmpty
        ? (uploadedImages.first['fileUrl'] ?? '').trim()
        : dish.imageUrl.trim();
    final primaryImageKey = uploadedImages.isNotEmpty
        ? (uploadedImages.first[_imageKeyField] ?? '').trim()
        : '';
    if (primaryImageUrl.isEmpty) {
      throw Exception('Dish imageUrl is required.');
    }

    final payload = dish.toMap();
    payload['imageUrl'] = primaryImageUrl;
    if (primaryImageKey.isNotEmpty) {
      payload[_imageKeyField] = primaryImageKey;
    }
    payload['createdAt'] = (dish.createdAt ?? DateTime.now()).toIso8601String();

    await apiClient.post('/dishes', body: payload);
  }
}
