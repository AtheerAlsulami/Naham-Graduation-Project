import 'dart:convert';

import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsFollowService {
  AwsFollowService({required this.apiClient});

  final AwsApiClient apiClient;

  Future<void> followCook({
    required String customerId,
    required String cookId,
  }) async {
    try {
      await apiClient.post(
        '/follows',
        body: {
          'customerId': customerId,
          'cookId': cookId,
        },
      );
    } on AwsApiException catch (error) {
      if (error.statusCode == 404) {
        await apiClient.post(
          '/follow',
          body: {
            'customerId': customerId,
            'cookId': cookId,
          },
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> unfollowCook({
    required String customerId,
    required String cookId,
  }) async {
    try {
      await apiClient.delete(
        '/follows',
        body: {
          'customerId': customerId,
          'cookId': cookId,
        },
      );
    } on AwsApiException catch (error) {
      if (error.statusCode == 404) {
        await apiClient.delete(
          '/follow',
          body: {
            'customerId': customerId,
            'cookId': cookId,
          },
        );
        return;
      }
      rethrow;
    }
  }

  Future<Set<String>> listFollowedCookIds(String customerId) async {
    try {
      final response = await apiClient.get(
        '/follows',
        queryParameters: {'customerId': customerId},
      );
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> &&
              decoded.containsKey('statusCode') &&
              decoded['body'] is String
          ? jsonDecode(decoded['body'] as String)
          : decoded;
      final items = body is Map<String, dynamic> ? body['items'] : null;
      if (items is! List) {
        return const {};
      }
      return items
          .whereType<Map>()
          .map((item) => item['cookId']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } on AwsApiException catch (error) {
      if (error.statusCode == 404) {
        final response = await apiClient.get(
          '/follow',
          queryParameters: {'customerId': customerId},
        );
        final decoded = jsonDecode(response.body);
        final body = decoded is Map<String, dynamic> &&
                decoded.containsKey('statusCode') &&
                decoded['body'] is String
            ? jsonDecode(decoded['body'] as String)
            : decoded;
        final items = body is Map<String, dynamic> ? body['items'] : null;
        if (items is! List) {
          return const {};
        }
        return items
            .whereType<Map>()
            .map((item) => item['cookId']?.toString().trim() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }
      rethrow;
    }
  }
}
