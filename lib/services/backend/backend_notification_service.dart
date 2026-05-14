import 'package:naham_app/core/models/notification_model.dart';
import 'package:naham_app/services/aws/aws_notification_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendNotificationService {
  BackendNotificationService()
      : _awsNotificationService = AwsNotificationService(
          apiClient: BackendFactory.createAwsNotificationsApiClient(),
        );

  final AwsNotificationService _awsNotificationService;

  Future<List<NotificationModel>> getNotifications({
    required String userId,
    required String userType,
  }) async {
    return _awsNotificationService.getNotifications(
      userId: userId,
      userType: userType,
    );
  }

  Future<NotificationModel> markAsRead(String notificationId) async {
    return _awsNotificationService.markAsRead(notificationId);
  }

  Future<NotificationModel> createNotification({
    required String userId,
    required String userType,
    required String title,
    String? subtitle,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    return _awsNotificationService.createNotification(
      userId: userId,
      userType: userType,
      title: title,
      subtitle: subtitle,
      type: type,
      data: data,
    );
  }
}
