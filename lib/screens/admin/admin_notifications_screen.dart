import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/models/notification_model.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/core/providers/notifications_provider.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/core/theme/app_theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      await context
          .read<NotificationsProvider>()
          .loadNotifications(user.id, 'admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        body: Column(
          children: [
            const _NotificationsHeader(),
            Expanded(
              child: Consumer<NotificationsProvider>(
                builder: (context, notificationsProvider, child) {
                  if (notificationsProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications = notificationsProvider.notifications;
                  final errorMessage = notificationsProvider.errorMessage;
                  if (errorMessage != null && notifications.isEmpty) {
                    return _StatusMessage(
                      message: errorMessage,
                      onRetry: _loadNotifications,
                    );
                  }
                  if (notifications.isEmpty) {
                    return const _StatusMessage(
                      message: 'No notifications yet',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: AppColors.homeChrome,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _AdminNotificationCard(
                          notification: notification,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, topPadding + 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            splashRadius: 22,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay updated with all platform activities',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationsProvider>().markAsRead(notification.id);
        }
        // Handle navigation based on notification type
        _handleNotificationTap(context, notification);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: _getBorderColor(notification.type), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _getIconBackground(notification.type),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(notification.type),
                size: 21,
                color: _getIconColor(notification.type),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9A19FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'New',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF5C6474),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        notification.timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8E95A4),
                          height: 1.1,
                        ),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 6),
                        const CircleAvatar(
                          radius: 2.8,
                          backgroundColor: Color(0xFF9A19FF),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor(String type) {
    switch (type) {
      case 'approval':
        return const Color(0xFFE1E3E8);
      case 'order':
        return const Color(0xFF9A19FF);
      default:
        return const Color(0xFFE1E3E8);
    }
  }

  Color _getIconBackground(String type) {
    switch (type) {
      case 'approval':
        return const Color(0xFFF3E9FF);
      case 'order':
        return const Color(0xFFF3E9FF);
      default:
        return const Color(0xFFF3E9FF);
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'approval':
        return Icons.person_add_alt_rounded;
      case 'order':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type) {
    return const Color(0xFF9A19FF);
  }

  void _handleNotificationTap(
      BuildContext context, NotificationModel notification) {
    switch (notification.type) {
      case 'approval':
        context.go(AppRoutes.cookVerification);
        break;
      case 'order':
        context.go(AppRoutes.adminOrders);
        break;
      default:
        break;
    }
  }
}
