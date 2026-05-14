import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_notification_service.dart';
import 'package:naham_app/services/backend/backend_config.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

void main() {
  test('BackendFactory exposes a notifications API client', () {
    final client = BackendFactory.createAwsNotificationsApiClient();

    expect(client.baseUrl, BackendConfig.awsNotificationsBaseUrl);
  });

  test('loads role-scoped notifications from the notifications API', () async {
    final recordingClient = _RecordingClient(
      responseBody: jsonEncode({
        'notifications': [
          {
            'id': 'notif_1',
            'userId': 'user_1',
            'userType': 'cook',
            'title': 'New order',
            'subtitle': 'Order #100',
            'type': 'order',
            'data': {'orderId': 'order_1'},
            'isRead': false,
            'createdAt': '2026-05-07T10:00:00.000Z',
          },
        ],
      }),
    );
    final service = AwsNotificationService(
      apiClient: AwsApiClient(
        baseUrl: 'https://notifications.example.com',
        client: recordingClient,
      ),
    );

    final notifications = await service.getNotifications(
      userId: 'user_1',
      userType: 'cook',
    );

    expect(notifications, hasLength(1));
    expect(notifications.single.userType, 'cook');
    expect(recordingClient.lastRequest!.method, 'GET');
    expect(
      recordingClient.lastRequest!.url.toString(),
      'https://notifications.example.com/notificationsList?userId=user_1&userType=cook',
    );
  });

  test('marks notifications as read using the request body expected by Flutter',
      () async {
    final recordingClient = _RecordingClient(
      responseBody: jsonEncode({
        'notification': {
          'id': 'notif_1',
          'userId': 'user_1',
          'userType': 'customer',
          'title': 'Order update',
          'subtitle': '',
          'type': 'order',
          'data': {},
          'isRead': true,
          'createdAt': '2026-05-07T10:00:00.000Z',
        },
      }),
    );
    final service = AwsNotificationService(
      apiClient: AwsApiClient(
        baseUrl: 'https://notifications.example.com',
        client: recordingClient,
      ),
    );

    final notification = await service.markAsRead('notif_1');

    expect(notification.isRead, isTrue);
    expect(recordingClient.lastRequest!.method, 'POST');
    expect(
      recordingClient.lastRequest!.url.toString(),
      'https://notifications.example.com/notificationsMarkRead',
    );
    expect(
      jsonDecode(recordingClient.lastBody!),
      {'notificationId': 'notif_1'},
    );
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient({
    required this.responseBody,
  });

  final String responseBody;
  http.BaseRequest? lastRequest;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) {
      lastBody = request.body;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
