import 'dart:convert';

import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsOrderService {
  AwsOrderService({required this.apiClient});

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

  Map<String, dynamic> _toMap(dynamic value, {required String context}) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw Exception('Invalid $context payload.');
  }

  List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, v) => MapEntry(key.toString(), v)))
        .toList(growable: false);
  }

  void _throwIfFailed(int statusCode, dynamic body) {
    if (statusCode < 400) return;
    final map = body is Map ? _toMap(body, context: 'error response') : null;
    final message = map?['message']?.toString() ?? 'Order request failed.';
    throw Exception(message);
  }

  Future<CustomerOrderModel> createOrder({
    required Map<String, dynamic> payload,
  }) async {
    final response = await apiClient.post('/orders', body: payload);
    final body = _decodePayload(response.body);
    _throwIfFailed(response.statusCode, body);
    final map = _toMap(body, context: 'create order');
    final order = _toMap(map['order'], context: 'create order -> order');
    return CustomerOrderModel.fromMap(order);
  }

  Future<List<CustomerOrderModel>> listOrders({
    String? customerId,
    String? cookId,
    String? status,
    int limit = 200,
  }) async {
    final response = await apiClient.get(
      '/orders',
      queryParameters: {
        'customerId': customerId,
        'cookId': cookId,
        'status': status,
        'limit': '$limit',
      },
    );
    final body = _decodePayload(response.body);
    _throwIfFailed(response.statusCode, body);
    if (body is List) {
      return _toListOfMaps(body).map(CustomerOrderModel.fromMap).toList();
    }
    final map = _toMap(body, context: 'list orders');
    final items = _toListOfMaps(map['items']);
    return items.map(CustomerOrderModel.fromMap).toList();
  }

  Future<CustomerOrderModel?> getOrderById(String orderId) async {
    final response = await apiClient.get('/orders/$orderId');
    final body = _decodePayload(response.body);
    _throwIfFailed(response.statusCode, body);
    final map = _toMap(body, context: 'get order');
    final orderData = map['order'];
    if (orderData == null) return null;
    return CustomerOrderModel.fromMap(
      _toMap(orderData, context: 'get order -> order'),
    );
  }

  Future<CustomerOrderModel> updateOrderStatus({
    required String orderId,
    String? status,
    String? action,
    int? rating,
    int? cookRating,
    int? serviceRating,
    String? reviewComment,
    String? issueReason,
    List<Map<String, dynamic>>? replacementItems,
  }) async {
    final response = await apiClient.post(
      '/orders/$orderId/status',
      body: {
        if (action != null) 'action': action,
        if (status != null) 'status': status,
        if (rating != null) 'rating': rating,
        if (cookRating != null) 'cookRating': cookRating,
        if (serviceRating != null) 'serviceRating': serviceRating,
        if (reviewComment != null) 'reviewComment': reviewComment,
        if (issueReason != null) 'issueReason': issueReason,
        if (replacementItems != null) 'replacementItems': replacementItems,
      },
    );
    final body = _decodePayload(response.body);
    _throwIfFailed(response.statusCode, body);
    final map = _toMap(body, context: 'update order status');
    final order = _toMap(map['order'], context: 'update order status -> order');
    return CustomerOrderModel.fromMap(order);
  }
}
