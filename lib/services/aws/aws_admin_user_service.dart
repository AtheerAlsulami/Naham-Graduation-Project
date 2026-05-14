import 'dart:convert';

import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';

class AwsAdminUserService {
  AwsAdminUserService({required this.apiClient});

  final AwsApiClient apiClient;

  Map<String, dynamic> _asJsonMap(dynamic value, {required String context}) {
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
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body') &&
        !decoded.containsKey('items')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  List<Map<String, dynamic>> _extractItems(dynamic payload) {
    final body = _asJsonMap(payload, context: 'admin users response');
    final rawItems = body['items'] ?? body['users'] ?? body['data'] ?? const [];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  AdminUserRecord _toRecord(Map<String, dynamic> map) {
    final rawStatus = (map['status'] ?? map['accountStatus'] ?? '').toString();
    final verificationIdUrl =
        (map['verificationIdUrl'] ?? '').toString().trim();
    final verificationHealthUrl =
        (map['verificationHealthUrl'] ?? '').toString().trim();
    return AdminUserRecord(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      role: (map['role'] ?? '').toString().trim().toLowerCase(),
      status: rawStatus.trim(),
      rating: _asDouble(map['rating']),
      orders: _asInt(map['totalOrders'] ?? map['orders']),
      complaints: map['complaintsCount'] == null && map['complaints'] == null
          ? null
          : _asInt(map['complaintsCount'] ?? map['complaints']),
      cookStatus: (map['cookStatus'] ?? '').toString().trim().isEmpty
          ? null
          : (map['cookStatus'] ?? '').toString().trim(),
      createdAt: _asDateTime(map['createdAt']),
      verificationIdUrl: verificationIdUrl.isEmpty ? null : verificationIdUrl,
      verificationHealthUrl:
          verificationHealthUrl.isEmpty ? null : verificationHealthUrl,
      isOnline: _asBool(map['isOnline']),
      documents: _asDocuments(
        map['documents'],
        verificationIdUrl: verificationIdUrl,
        verificationHealthUrl: verificationHealthUrl,
      ),
    );
  }

  List<AdminUserDocument>? _asDocuments(
    dynamic value, {
    required String verificationIdUrl,
    required String verificationHealthUrl,
  }) {
    final documents = <AdminUserDocument>[];
    if (value is List) {
      documents.addAll(value.map((item) {
        if (item is Map<String, dynamic>) {
          return AdminUserDocument(
            title: (item['title'] ?? '').toString(),
            url: (item['url'] ?? '').toString(),
            type: (item['type'] ?? '').toString(),
          );
        }
        return null;
      }).whereType<AdminUserDocument>());
    }

    if (verificationIdUrl.isNotEmpty &&
        !documents.any((item) => item.url == verificationIdUrl)) {
      documents.add(
        AdminUserDocument(
          title: 'Identity document',
          url: verificationIdUrl,
          type: 'id',
        ),
      );
    }
    if (verificationHealthUrl.isNotEmpty &&
        !documents.any((item) => item.url == verificationHealthUrl)) {
      documents.add(
        AdminUserDocument(
          title: 'Health certificate',
          url: verificationHealthUrl,
          type: 'health',
        ),
      );
    }

    return documents.isEmpty ? null : documents;
  }

  Future<List<AdminUserRecord>> listUsers({
    String? role,
    int limit = 500,
  }) async {
    final normalizedRole = role?.trim();
    final response = await apiClient.get(
      '/users',
      queryParameters: {
        if (normalizedRole != null && normalizedRole.isNotEmpty)
          'role': normalizedRole,
        'limit': '$limit',
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final items = _extractItems(payload);
    return items.map(_toRecord).where((item) => item.id.isNotEmpty).toList();
  }

  Future<AdminUserRecord> createUser(CreateAdminUserRequest request) async {
    final response = await apiClient.post(
      '/users',
      body: {
        'name': request.name.trim(),
        'email': request.email.trim(),
        'phone': request.phone.trim(),
        'password': request.password,
        'role': request.role.trim().toLowerCase(),
        'status': request.status.trim(),
        'rating': request.rating,
        'totalOrders': request.orders,
        'complaintsCount': request.complaints,
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'admin create user response');
    final userMap = _asJsonMap(body['user'] ?? body['item'] ?? body,
        context: 'created user');
    final user = _toRecord(userMap);
    if (user.id.isEmpty) {
      throw Exception('User creation response did not include user id.');
    }
    return user;
  }

  Future<AdminUserRecord?> updateUserStatus({
    required String id,
    required String status,
    String? cookStatus,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required for status update.');
    }

    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.isEmpty) {
      throw Exception('Status is required for status update.');
    }

    final response = await apiClient.put(
      '/users/$normalizedId',
      body: {
        'status': normalizedStatus,
        if ((cookStatus ?? '').trim().isNotEmpty)
          'cookStatus': cookStatus!.trim().toLowerCase(),
      },
    );

    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'admin update user response');
    final rawUser = body['user'] ?? body['item'] ?? body;
    final userMap = _asJsonMap(rawUser, context: 'updated user');
    final updated = _toRecord(userMap);
    if (updated.id.isEmpty) {
      return null;
    }
    return updated;
  }

  Future<void> deleteUser(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required for delete.');
    }
    await apiClient.delete('/users/$normalizedId');
  }
}
