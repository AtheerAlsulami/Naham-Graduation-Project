import 'package:flutter/widgets.dart';
import 'package:naham_app/core/models/notification_model.dart';
import 'package:naham_app/services/backend/backend_notification_service.dart';

class NotificationsProvider with ChangeNotifier {
  final BackendNotificationService _notificationService;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUserKey;

  NotificationsProvider(this._notificationService);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void bindAuthUser({
    required String? userId,
    required String? userType,
  }) {
    final nextKey =
        userId == null || userType == null ? null : '$userType:$userId';
    if (nextKey == _activeUserKey) {
      return;
    }
    _activeUserKey = nextKey;
    _notifications = [];
    _errorMessage = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasListeners) {
        return;
      }
      notifyListeners();
    });
  }

  Future<void> loadNotifications(String userId, String userType) async {
    final nextKey = '$userType:$userId';
    if (nextKey != _activeUserKey) {
      _activeUserKey = nextKey;
      _notifications = [];
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications(
        userId: userId,
        userType: userType,
      );
    } catch (e) {
      _errorMessage = 'Failed to load notifications.';
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final updatedNotification =
          await _notificationService.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = updatedNotification;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update notification.';
      notifyListeners();
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String userType,
    required String title,
    String? subtitle,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final newNotification = await _notificationService.createNotification(
        userId: userId,
        userType: userType,
        title: title,
        subtitle: subtitle,
        type: type,
        data: data,
      );
      _notifications.insert(0, newNotification);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to create notification.';
      notifyListeners();
      debugPrint('Error creating notification: $e');
    }
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
}
