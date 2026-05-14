import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_order_service.dart';

void main() {
  test('AwsOrderService.createOrder posts order payload and parses order',
      () async {
    final client = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://orders.example.com/orders');
      expect(jsonDecode(body)['customerId'], 'customer_1');
      return _jsonResponse({'order': _orderJson(status: 'pending_review')});
    });
    final service = AwsOrderService(
      apiClient: AwsApiClient(
        baseUrl: 'https://orders.example.com',
        client: client,
      ),
    );

    final order = await service.createOrder(
      payload: {
        'customerId': 'customer_1',
        'cookId': 'cook_1',
        'items': [
          {'dishId': 'dish_1', 'dishName': 'Kabsa', 'quantity': 1, 'price': 30},
        ],
      },
    );

    expect(order.id, 'order_1');
    expect(order.status, CustomerOrderStatus.pendingReview);
  });

  test('AwsOrderService.updateOrderStatus sends confirm_received action',
      () async {
    final client = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/orders/order_1/status');
      expect(jsonDecode(body), {'action': 'confirm_received'});
      return _jsonResponse({
        'order': _orderJson(
          status: 'delivered',
          confirmedReceivedAt: '2026-05-11T10:00:00.000Z',
          deliveredAt: '2026-05-11T10:00:00.000Z',
          payoutId: 'payout_order_1_abc',
        ),
      });
    });
    final service = AwsOrderService(
      apiClient: AwsApiClient(
        baseUrl: 'https://orders.example.com',
        client: client,
      ),
    );

    final order = await service.updateOrderStatus(
      orderId: 'order_1',
      action: 'confirm_received',
    );

    expect(order.status, CustomerOrderStatus.delivered);
    expect(order.confirmedReceivedAt, isNotNull);
    expect(order.payoutId, startsWith('payout_order_1'));
  });

  test('AwsOrderService surfaces backend rating validation failures', () async {
    final client = _RecordingClient((request, body) async {
      expect(jsonDecode(body), {
        'action': 'rate',
        'cookRating': 5,
        'serviceRating': 4,
      });
      return _jsonResponse(
        {
          'message': 'rate is not allowed while order is pending_review.',
          'status': 'pending_review',
        },
        statusCode: 409,
      );
    });
    final service = AwsOrderService(
      apiClient: AwsApiClient(
        baseUrl: 'https://orders.example.com',
        client: client,
      ),
    );

    expect(
      () => service.updateOrderStatus(
        orderId: 'order_1',
        action: 'rate',
        cookRating: 5,
        serviceRating: 4,
      ),
      throwsA(isA<AwsApiException>()),
    );
  });
}

Map<String, dynamic> _orderJson({
  required String status,
  String? confirmedReceivedAt,
  String? deliveredAt,
  String payoutId = '',
}) {
  return {
    'id': 'order_1',
    'displayId': '#ORD-1',
    'customerId': 'customer_1',
    'customerName': 'Customer',
    'cookId': 'cook_1',
    'cookName': 'Cook',
    'status': status,
    'dishId': 'dish_1',
    'dishName': 'Kabsa',
    'imageUrl': '',
    'itemCount': 1,
    'items': [
      {'dishId': 'dish_1', 'dishName': 'Kabsa', 'quantity': 1, 'price': 30},
    ],
    'subtotal': 30,
    'deliveryFee': 5,
    'totalAmount': 35,
    'cookEarnings': 28.5,
    'rating': 0,
    'payoutId': payoutId,
    'createdAt': '2026-05-11T09:00:00.000Z',
    if (confirmedReceivedAt != null) 'confirmedReceivedAt': confirmedReceivedAt,
    if (deliveredAt != null) 'deliveredAt': deliveredAt,
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request, String body)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final response = await handler(request, body);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
