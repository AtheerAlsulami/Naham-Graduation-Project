import 'dart:convert';

import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsCookService {
  AwsCookService({required this.apiClient});

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
      if (trimmed.contains('Hello from Lambda')) {
        throw Exception(
          'AWS route is not connected correctly. '
          'Endpoint returned "$trimmed" instead of cooks JSON.',
        );
      }
      final decoded = jsonDecode(trimmed);
      return _asJsonMap(
        decoded,
        context: '$context (decoded from JSON string)',
      );
    }
    throw Exception('Invalid $context. Got ${value.runtimeType}.');
  }

  dynamic _decodeResponsePayload(String bodyString) {
    final decoded = jsonDecode(bodyString);
    if (decoded is Map<String, dynamic>) {
      final looksLikeProxyEnvelope = decoded.containsKey('statusCode') &&
          decoded.containsKey('body') &&
          !decoded.containsKey('items') &&
          !decoded.containsKey('users');
      if (looksLikeProxyEnvelope) {
        final nested = decoded['body'];
        if (nested is String) {
          return jsonDecode(nested);
        }
        return nested;
      }
    }
    return decoded;
  }

  List<Map<String, dynamic>> _extractUserList(dynamic payload) {
    if (payload is List) {
      if (payload.length == 1 && payload.first is Map) {
        final wrapper = payload.first;
        if (wrapper is Map) {
          final wrappedItems =
              wrapper['items'] ?? wrapper['users'] ?? wrapper['data'];
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
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }

    final body = _asJsonMap(payload, context: 'users response');
    final candidates = body['items'] ?? body['users'] ?? body['data'] ?? const [];
    if (candidates is! List) {
      return const [];
    }
    return candidates
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<List<UserModel>> getAvailableCooks() async {
    final response = await apiClient.get(
      '/users',
      queryParameters: {
        'role': AppConstants.roleCook,
      },
    );

    final payload = _decodeResponsePayload(response.body);
    final items = _extractUserList(payload);

    return items
        .map(
            (item) => UserModel.fromMap(_asJsonMap(item, context: 'cook item')))
        .toList();
  }
}
