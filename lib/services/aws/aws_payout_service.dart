import 'dart:convert';

import 'package:naham_app/models/payout_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsPayoutService {
  AwsPayoutService({required this.apiClient});

  final AwsApiClient apiClient;

  dynamic _decodePayload(String rawBody) {
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  Future<List<PayoutModel>> listPayouts({required String cookId}) async {
    final response = await apiClient.get(
      '/payouts',
      queryParameters: {'cookId': cookId},
    );
    final body = _decodePayload(response.body);
    final map = _toMap(body);
    if (response.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? 'Failed to load payouts.');
    }
    final rawItems = map['payouts'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .map(PayoutModel.fromMap)
        .toList(growable: false);
  }
}
