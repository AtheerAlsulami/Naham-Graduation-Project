import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:naham_app/core/providers/notifications_provider.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/auth_provider.dart';

/// Service that monitors the cook's scheduled working hours and
/// automatically toggles their online/offline status.
///
/// When a transition is detected (entering or leaving scheduled hours):
///   - Calls [AuthProvider.updateCookSettings] to persist the change
///   - Sends a notification via [NotificationsProvider]
///
/// Manual overrides are respected until the schedule naturally re-aligns
/// with the cook's current state.
class CookScheduleService {
  CookScheduleService({
    required this.authProvider,
    required this.notificationsProvider,
  });

  final AuthProvider authProvider;
  final NotificationsProvider notificationsProvider;

  Timer? _timer;

  /// The last auto-scheduled state (true = online, false = offline).
  /// Null when no auto-action has been taken yet.
  bool? _lastAutoState;

  /// True when the cook has manually toggled their status, preventing
  /// the auto-scheduler from overriding until the schedule catches up.
  bool _manualOverride = false;

  static const _checkInterval = Duration(seconds: 60);

  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// Starts the periodic schedule checker.
  void start() {
    _timer?.cancel();
    _lastAutoState = null;
    _manualOverride = false;

    // Run an immediate check, then periodically.
    _check();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  /// Stops the periodic schedule checker.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call this when the cook manually toggles their online/offline status.
  /// Flags the override so the auto-scheduler doesn't interfere, and sends
  /// a "manual toggle" notification.
  void onManualToggle(bool newValue) {
    _manualOverride = true;
    _lastAutoState = null;

    final user = authProvider.currentUser;
    if (user != null) {
      _sendNotification(user, newValue, isAutomatic: false);
    }
  }

  void _check() {
    final user = authProvider.currentUser;
    if (user == null) return;

    final shouldBeOnline = _isInWorkingHours(user.workingHours);

    // If the cook manually overrode, wait until the schedule state
    // matches their current state before clearing the override.
    if (_manualOverride) {
      if (shouldBeOnline == (user.isOnline ?? false)) {
        _manualOverride = false;
        _lastAutoState = shouldBeOnline;
      }
      return;
    }

    // First check: just record the initial state without acting.
    if (_lastAutoState == null) {
      _lastAutoState = shouldBeOnline;
      return;
    }

    // No transition detected.
    if (shouldBeOnline == _lastAutoState) return;

    _lastAutoState = shouldBeOnline;

    debugPrint(
      '[CookScheduleService] Auto-toggling to '
      '${shouldBeOnline ? "online" : "offline"}',
    );

    // Optimistic UI update.
    authProvider.updateUser(user.copyWith(isOnline: shouldBeOnline));
    authProvider.updateCookSettings(isOnline: shouldBeOnline);

    _sendNotification(user, shouldBeOnline, isAutomatic: true);
  }

  bool _isInWorkingHours(Map<String, dynamic>? workingHours) {
    if (workingHours == null) return false;

    final now = DateTime.now();
    // DateTime.weekday: Monday=1 … Sunday=7 → map to Sunday=0-based index.
    final todayIndex = now.weekday % 7;
    final today = _dayNames[todayIndex];

    final slot = workingHours[today];
    if (slot == null || slot is! Map<String, dynamic>) return false;
    if (slot['isActive'] != true) return false;

    final start = slot['start'] as int?;
    final end = slot['end'] as int?;
    if (start == null || end == null) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= start && currentMinutes <= end;
  }

  void _sendNotification(
    UserModel user,
    bool isOnline, {
    required bool isAutomatic,
  }) {
    final title = isOnline
        ? '🟢 Your kitchen is now online'
        : '🔴 Your kitchen is now offline';

    final subtitle = isAutomatic
        ? 'Automatically set based on your working hours schedule'
        : 'You manually changed your availability';

    notificationsProvider
        .createNotification(
      userId: user.id,
      userType: user.role,
      title: title,
      subtitle: subtitle,
      type: 'shift_status',
      data: {
        'isOnline': isOnline,
        'isAutomatic': isAutomatic,
        'timestamp': DateTime.now().toIso8601String(),
      },
    )
        .catchError((e) {
      debugPrint('[CookScheduleService] Failed to send notification: $e');
    });
  }
}
