import 'dart:convert';

import 'package:naham_app/core/models/notification_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/backend/backend_config.dart';

class AwsNotificationService {
  AwsNotificationService({
    AwsApiClient? apiClient,
  }) : apiClient = apiClient ??
            AwsApiClient(baseUrl: BackendConfig.awsNotificationsBaseUrl);

  final AwsApiClient apiClient;

  Future<List<NotificationModel>> getNotifications({
    required String userId,
    required String userType,
  }) async {
    final response = await apiClient.get(
      '/notificationsList',
      queryParameters: {
        'userId': userId,
        'userType': userType,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['notifications'] as List)
          .map((item) => NotificationModel.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  Future<NotificationModel> markAsRead(String notificationId) async {
    final response = await apiClient.post(
      '/notificationsMarkRead',
      body: {'notificationId': notificationId},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return NotificationModel.fromJson(data['notification']);
    } else {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<NotificationModel> createNotification({
    required String userId,
    required String userType,
    required String title,
    String? subtitle,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final response = await apiClient.post(
      '/notificationsSave',
      body: {
        'userId': userId,
        'userType': userType,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'data': data,
      },
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return NotificationModel.fromJson(data['notification']);
    } else {
      throw Exception('Failed to create notification');
    }
  }
}
