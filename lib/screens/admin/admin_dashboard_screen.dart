import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().initializeIfNeeded(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final unreadSupportCount = context.watch<ChatProvider>().unreadSupportCount;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            _DashboardTopBar(
              topPadding: topPadding,
              onAlertTap: _openNotificationsScreen,
              onQuickLogoutTap: _quickLogout,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    if (unreadSupportCount > 0) ...[
                      _MessagesAndComplaintsCard(
                        newCount: unreadSupportCount,
                        onTap: () => context.push(AppRoutes.adminChatSupport),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF252C37),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildQuickActionsGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = <_AdminQuickAction>[
      const _AdminQuickAction(
        id: 'orders',
        title: 'Orders',
        subtitle: 'Manage live orders',
        icon: Icons.inventory_2_outlined,
        iconColor: Color(0xFF7A69FF),
      ),
      const _AdminQuickAction(
        id: 'approvals',
        title: 'Approvals',
        subtitle: 'Verify new users',
        icon: Icons.check_circle_outline_rounded,
        iconColor: Color(0xFF53C476),
      ),
      const _AdminQuickAction(
        id: 'users',
        title: 'Users',
        subtitle: 'Customers & cooks',
        icon: Icons.people_outline_rounded,
        iconColor: Color(0xFF7A69FF),
      ),
      const _AdminQuickAction(
        id: 'reports',
        title: 'Reports',
        subtitle: 'Analytics & stats',
        icon: Icons.description_outlined,
        iconColor: Color(0xFF7A69FF),
      ),
      const _AdminQuickAction(
        id: 'hygiene',
        title: 'Hygiene',
        subtitle: 'Quality checks',
        icon: Icons.fact_check_outlined,
        iconColor: Color(0xFF7A69FF),
      ),
      const _AdminQuickAction(
        id: 'chat',
        title: 'Chat & Help',
        subtitle: 'Support tickets',
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: Color(0xFF7A69FF),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      itemCount: actions.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _QuickActionCard(
          action: action,
          onTap: () => _handleQuickAction(action.id),
        );
      },
    );
  }

  void _handleQuickAction(String id) {
    switch (id) {
      case 'orders':
        context.push(AppRoutes.adminOrders);
        return;
      case 'approvals':
        context.push(AppRoutes.cookVerification);
        return;
      case 'users':
        context.push(AppRoutes.userManagement);
        return;
      case 'reports':
        context.push(AppRoutes.adminReports);
        return;
      case 'hygiene':
        context.push(AppRoutes.adminHygieneInspections);
        return;
      case 'chat':
        context.push(AppRoutes.adminChatSupport);
        return;
      default:
        _showSnack('Action not available.');
        return;
    }
  }

  void _openNotificationsScreen() {
    context.push(AppRoutes.adminNotifications);
  }

  Future<void> _quickLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.login);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.topPadding,
    required this.onAlertTap,
    required this.onQuickLogoutTap,
  });

  final double topPadding;
  final VoidCallback onAlertTap;
  final VoidCallback onQuickLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, Admin',
                  style: GoogleFonts.poppins(
                    fontSize: 13.2,
                    color: const Color(0xFFF0EEFF),
                  ),
                ),
              ],
            ),
          ),
          _NotificationButton(onTap: onAlertTap),
          const SizedBox(width: 8),
          _QuickLogoutButton(onTap: onQuickLogoutTap),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: Color(0xFF6E7484),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE84343),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogoutButton extends StatelessWidget {
  const _QuickLogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.logout_rounded,
          size: 20,
          color: Color(0xFFE04A4A),
        ),
      ),
    );
  }
}

class _MessagesAndComplaintsCard extends StatelessWidget {
  const _MessagesAndComplaintsCard({
    required this.newCount,
    required this.onTap,
  });

  final int newCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7766EF), Color(0xFF6C56E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x226B56E8),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New messages\n& complaints',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to respond to pending inquiries',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$newCount New',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7160EA),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.action,
    required this.onTap,
  });

  final _AdminQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E7ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: action.iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action.icon,
                  size: 16,
                  color: action.iconColor,
                ),
              ),
              const Spacer(),
              Text(
                action.title,
                style: GoogleFonts.poppins(
                  fontSize: 16.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E3442),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: const Color(0xFFA1A8B6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminQuickAction {
  const _AdminQuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
}
