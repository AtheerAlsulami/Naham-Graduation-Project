import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/providers/notifications_provider.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/customer_order_model.dart';

import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:naham_app/services/cook_schedule_service.dart';
import 'package:provider/provider.dart';

class CookDashboardScreen extends StatefulWidget {
  const CookDashboardScreen({super.key});
  @override
  State<CookDashboardScreen> createState() => _CookDashboardScreenState();
}

class _CookDashboardScreenState extends State<CookDashboardScreen> {
  bool _hasDelayedOrdersDismissed = false;
  bool _hasUnreadNotifications = true;

  int _dailyCapacity = 0;

  CookScheduleService? _scheduleService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleService = CookScheduleService(
        authProvider: context.read<AuthProvider>(),
        notificationsProvider: context.read<NotificationsProvider>(),
      );
      _scheduleService!.start();
      context.read<OrdersProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _scheduleService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isOnline = user?.isOnline ?? false;
    final kitchenName = _resolveKitchenName(user?.displayName ?? user?.name);

    final ordersProvider = context.watch<OrdersProvider>();
    final hasNewOrders = ordersProvider.orders
        .any((order) => order.status == CustomerOrderStatus.pendingReview);
    final hasDelayedOrders = !_hasDelayedOrdersDismissed &&
        hasNewOrders &&
        ordersProvider.orders.any((order) => order.isLateForDelivery);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Column(
          children: [
            _CookTopBar(
              hasNotification: _hasUnreadNotifications,
              onNotificationTap: _openNotificationsScreen,
            ),
            _CookStatusHeader(
              kitchenName: kitchenName,
              isOnline: isOnline,
              onStatusChanged: _toggleOnlineStatus,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
                child: Column(
                  children: [
                    if (isOnline && hasDelayedOrders) ...[
                      _DelayedOrdersCard(onTap: _showDelayedOrdersSheet),
                      const SizedBox(height: 16),
                    ],
                    _CapacityCard(
                      capacity: _dailyCapacity,
                      onTap: _showCapacitySheet,
                    ),
                    const SizedBox(height: 18),
                    _WorkingHoursCard(
                      workingHours: user?.workingHours,
                      onEditTap: _showWorkingHoursSheet,
                      onExtendTap: _extendToday,
                      onOpenTonightTap: _openTonightOnly,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 2,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }

  String _resolveKitchenName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return "Maria's Kitchen";
    if (trimmed.toLowerCase().contains('kitchen')) return trimmed;
    return "$trimmed's Kitchen";
  }

  void _toggleOnlineStatus(bool value) async {
    final auth = context.read<AuthProvider>();
    // Optimistic update: immediately update the user model so the UI reacts
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      auth.updateUser(currentUser.copyWith(isOnline: value));
    }
    // Notify the schedule service of a manual override
    _scheduleService?.onManualToggle(value);
    final success = await auth.updateCookSettings(isOnline: value);
    if (!mounted) return;
    if (!success) {
      // Revert the optimistic update
      if (currentUser != null) {
        auth.updateUser(currentUser.copyWith(isOnline: !value));
      }
      _showSnack('Failed to update status');
      return;
    }
    _showSnack(value ? 'Your kitchen is online' : 'Your kitchen is offline');
  }

  void _extendToday() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final today = days[DateTime.now().weekday - 1];

      final currentHours = user.workingHours != null
          ? Map<String, dynamic>.from(user.workingHours!)
          : <String, dynamic>{};
      final todaySlot = currentHours[today] as Map<String, dynamic>? ??
          {'isActive': true, 'start': 16 * 60, 'end': 22 * 60};

      final nextEnd =
          ((todaySlot['end'] as int) + 120).clamp(0, 24 * 60).toInt();
      todaySlot['end'] = nextEnd;
      todaySlot['isActive'] = true;
      currentHours[today] = todaySlot;

      await auth.updateCookSettings(workingHours: currentHours, isOnline: true);
    }

    _showSnack('Today extended by 2 hours');
  }

  void _openTonightOnly() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final today = days[DateTime.now().weekday - 1];

      final currentHours = user.workingHours != null
          ? Map<String, dynamic>.from(user.workingHours!)
          : <String, dynamic>{};
      currentHours[today] = {
        'isActive': true,
        'start': 18 * 60,
        'end': 23 * 60 + 30
      };

      await auth.updateCookSettings(workingHours: currentHours, isOnline: true);
    }

    _showSnack('Tonight-only availability is active');
  }

  void _openNotificationsScreen() {
    setState(() => _hasUnreadNotifications = false);
    context.push(AppRoutes.cookNotifications);
  }

  void _handleBottomNavTap(int index) {
    if (index == 2) return;
    if (index == 0) {
      context.go(AppRoutes.cookReels);
      return;
    }
    if (index == 5) {
      context.go(AppRoutes.cookPublicProfile);
      return;
    }
    if (index == 1) {
      context.go(AppRoutes.cookOrders);
      return;
    }
    if (index == 4) {
      context.go(AppRoutes.myMenu);
      return;
    }
    if (index == 3) {
      context.go(AppRoutes.cookChat);
    }
  }

  void _showDelayedOrdersSheet() {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return _CookSheet(
          title: 'Delayed Orders Action',
          message:
              'Review delayed orders and confirm preparation times before accepting more requests.',
          primaryLabel: 'Review',
          secondaryLabel: 'Dismiss',
          onPrimaryTap: () {
            Navigator.of(context).pop();
            setState(() => _hasUnreadNotifications = false);
            parentContext.go(AppRoutes.cookOrders);
          },
          onSecondaryTap: () {
            Navigator.of(context).pop();
            setState(() {
              _hasDelayedOrdersDismissed = true;
              _hasUnreadNotifications = false;
            });
            _showSnack('Delayed order alert dismissed');
          },
        );
      },
    );
  }

  void _showCapacitySheet() {
    var selectedCapacity = _dailyCapacity;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _CapacitySheet(
              capacity: selectedCapacity,
              onDecrease: () => setSheetState(() {
                selectedCapacity = (selectedCapacity - 1).clamp(0, 60).toInt();
              }),
              onIncrease: () => setSheetState(() {
                selectedCapacity = (selectedCapacity + 1).clamp(0, 60).toInt();
              }),
              onSave: () async {
                setState(() => _dailyCapacity = selectedCapacity);
                Navigator.of(context).pop();

                final auth = context.read<AuthProvider>();
                final success = await auth.updateCookSettings(
                    dailyCapacity: selectedCapacity);
                if (mounted) {
                  if (success) {
                    _showSnack('Daily capacity updated to $selectedCapacity');
                  } else {
                    _showSnack('Failed to update capacity');
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  void _showWorkingHoursSheet() {
    context.push(AppRoutes.cookWorkingHours);
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

class _CookTopBar extends StatelessWidget {
  const _CookTopBar({
    required this.hasNotification,
    required this.onNotificationTap,
  });

  final bool hasNotification;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: topPadding + 82,
      padding: EdgeInsets.fromLTRB(28, topPadding + 18, 22, 0),
      color: AppColors.homeChrome,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Image.asset('assets/naham_logo.png', fit: BoxFit.contain),
          ),
          const Spacer(),
          Tooltip(
            message: 'Notifications',
            child: Semantics(
              button: true,
              label: 'Notifications',
              child: GestureDetector(
                onTap: onNotificationTap,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      if (hasNotification)
                        Positioned(
                          right: 1,
                          top: 2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.homeBadgeRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CookStatusHeader extends StatelessWidget {
  const _CookStatusHeader({
    required this.kitchenName,
    required this.isOnline,
    required this.onStatusChanged,
  });

  final String kitchenName;
  final bool isOnline;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(20, 10, 18, 10),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.homeChrome.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bakery_dining_outlined,
              size: 20,
              color: AppColors.homeChrome,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              kitchenName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.homeChrome,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  isOnline ? const Color(0xFFDFF6E7) : const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isOnline ? 'On Shift' : 'Off Shift',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isOnline
                    ? const Color(0xFF2EA05B)
                    : const Color(0xFFB38100),
              ),
            ),
          ),
          _CookAvailabilitySwitch(
            value: isOnline,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _CookAvailabilitySwitch extends StatelessWidget {
  const _CookAvailabilitySwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackColor =
        value ? const Color(0xFF42B85D) : const Color(0xFF8B8B8B);

    return Tooltip(
      message: value ? 'Set offline' : 'Set online',
      child: Semantics(
        button: true,
        toggled: value,
        label: value ? 'Kitchen online' : 'Kitchen offline',
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 50,
                  height: 29,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: value ? const Color(0xFF42B85D) : Colors.black45,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DelayedOrdersCard extends StatelessWidget {
  const _DelayedOrdersCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Review delayed orders',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF1D3D2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const _AlertIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delayed Orders Action',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9B3036),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review required immediately',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFCF5D63),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertIcon extends StatelessWidget {
  const _AlertIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE5E5),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 19,
        color: Color(0xFFFF6363),
      ),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({
    required this.capacity,
    required this.onTap,
  });

  final int capacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Set daily cooking capacity, current capacity $capacity dishes',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB716FF), Color(0xFF9C31FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A9C31FF),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.room_service_outlined,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Cooking Capacity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Set how many dishes you'll cook today",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({
    required this.workingHours,
    required this.onEditTap,
    required this.onExtendTap,
    required this.onOpenTonightTap,
  });

  final Map<String, dynamic>? workingHours;
  final VoidCallback onEditTap;
  final VoidCallback onExtendTap;
  final VoidCallback onOpenTonightTap;

  static const List<String> _dayOrder = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String _getTimeForDay(String day) {
    if (workingHours == null) return 'Not set';
    final slot = workingHours![day];
    if (slot == null) return 'Not set';
    if (slot is Map<String, dynamic>) {
      if (slot['isActive'] == false) return 'Closed';
      final start = slot['start'] as int?;
      final end = slot['end'] as int?;
      if (start == null || end == null) return 'Not set';
      return '${_formatMinute(start)} - ${_formatMinute(end)}';
    }
    return 'Not set';
  }

  bool _isDayActive(String day) {
    if (workingHours == null) return false;
    final slot = workingHours![day];
    if (slot == null) return false;
    if (slot is Map<String, dynamic>) {
      return slot['isActive'] == true;
    }
    return false;
  }

  static String _formatMinute(int minuteOfDay) {
    final hours24 = minuteOfDay ~/ 60;
    final minutes = minuteOfDay % 60;
    final isPm = hours24 >= 12;
    final hours12 = hours24 % 12 == 0 ? 12 : hours24 % 12;
    final minuteLabel = minutes.toString().padLeft(2, '0');
    final period = isPm ? 'PM' : 'AM';
    return '$hours12.$minuteLabel $period';
  }

  int get _todayIndex {
    // DateTime.weekday: Monday=1...Sunday=7, our array: Sunday=0...Saturday=6
    return DateTime.now().weekday % 7;
  }

  bool _isCurrentlyInWorkingHours() {
    final today = _dayOrder[_todayIndex];
    if (!_isDayActive(today)) return false;
    final slot = workingHours?[today];
    if (slot == null || slot is! Map<String, dynamic>) return false;
    final start = slot['start'] as int?;
    final end = slot['end'] as int?;
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= start && currentMinutes <= end;
  }

  @override
  Widget build(BuildContext context) {
    final isInWorkHours = _isCurrentlyInWorkingHours();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE7E5E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 18,
                color: Color(0xFFA31FFF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Working Hours',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF303445),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isInWorkHours
                      ? const Color(0xFFDFF6E7)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isInWorkHours ? '● Active Now' : '○ Off Hours',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isInWorkHours
                        ? const Color(0xFF2EA05B)
                        : const Color(0xFF999FAA),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallOutlinedButton(
                label: 'Edit',
                onTap: onEditTap,
                width: 44,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_dayOrder.length, (i) {
            final day = _dayOrder[i];
            final isToday = i == _todayIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _WorkingHourRow(
                day: day,
                time: _getTimeForDay(day),
                highlight: isToday,
              ),
            );
          }),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compact = width < 320;
              final buttonWidth = compact ? width : (width - 8) / 2;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: _SmallOutlinedButton(
                      label: 'Extend Today +2h',
                      onTap: onExtendTap,
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: _SmallOutlinedButton(
                      label: 'Open Tonight Only',
                      onTap: onOpenTonightTap,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkingHourRow extends StatelessWidget {
  const _WorkingHourRow({
    required this.day,
    required this.time,
    this.highlight = false,
  });

  final String day;
  final String time;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF1DFFF) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(5),
        border: highlight ? Border.all(color: const Color(0xFFE0B7FF)) : null,
      ),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Text(
              day,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight
                    ? const Color(0xFF8C39BB)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight
                    ? const Color(0xFF8C39BB)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (highlight) ...[
            const SizedBox(width: 8),
            Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFA51FFF),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Today',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallOutlinedButton extends StatelessWidget {
  const _SmallOutlinedButton({
    required this.label,
    required this.onTap,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF303445),
          side: const BorderSide(color: Color(0xFFE4E4E7)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class CookBottomNavBar extends StatelessWidget {
  const CookBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_CookNavEntry> _entries = [
    _CookNavEntry(index: 0, icon: Icons.play_arrow_rounded, label: 'Reels'),
    _CookNavEntry(index: 1, icon: Icons.receipt_long_rounded, label: 'Orders'),
    _CookNavEntry(index: 2, icon: Icons.home_rounded, label: 'Home'),
    _CookNavEntry(index: 3, icon: Icons.chat_bubble_rounded, label: 'Chat'),
    _CookNavEntry(index: 4, icon: Icons.restaurant_rounded, label: 'Menu'),
    _CookNavEntry(index: 5, icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeEntry = _entries.firstWhere(
      (entry) => entry.index == currentIndex,
      orElse: () => _entries[2],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 12.0;
        final activeSlot = _entries.indexOf(activeEntry);
        final itemWidth =
            (constraints.maxWidth - (horizontalPadding * 2)) / _entries.length;
        final activeLeft =
            horizontalPadding + (itemWidth * activeSlot) + (itemWidth / 2) - 28;

        return SizedBox(
          height: 92,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.homeChrome,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 18,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: _entries
                        .map(
                          (entry) => Expanded(
                            child: _CookNavButton(
                              entry: entry,
                              currentIndex: currentIndex,
                              onTap: onTap,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              Positioned(
                top: -4,
                left: activeLeft,
                child: Tooltip(
                  message: activeEntry.label,
                  child: Semantics(
                    button: true,
                    selected: true,
                    label: activeEntry.label,
                    child: GestureDetector(
                      onTap: () => onTap(activeEntry.index),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.homeChrome,
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              activeEntry.icon,
                              size: activeEntry.index == 0 ? 28 : 24,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeEntry.label,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CookNavButton extends StatelessWidget {
  const _CookNavButton({
    required this.entry,
    required this.currentIndex,
    required this.onTap,
  });

  final _CookNavEntry entry;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == entry.index;

    return Tooltip(
      message: entry.label,
      child: Semantics(
        button: true,
        selected: isActive,
        label: entry.label,
        child: InkWell(
          onTap: () => onTap(entry.index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.icon,
                  size: 20,
                  color: Colors.white.withValues(alpha: isActive ? 0.0 : 0.76),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.72),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CookNavEntry {
  const _CookNavEntry({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;
}

class _CookSheet extends StatelessWidget {
  const _CookSheet({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 20),
          Row(
            children: [
              const _AlertIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9B3036),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9B3036),
                    side: const BorderSide(color: Color(0xFFF0CBCD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimaryTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.homeChrome,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapacitySheet extends StatelessWidget {
  const _CapacitySheet({
    required this.capacity,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSave,
  });

  final int capacity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 20),
          Text(
            'Daily Cooking Capacity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how many dishes you can cook today.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.homeMintSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.homeCardBorder),
            ),
            child: Row(
              children: [
                _CapacityStepperButton(
                  icon: Icons.remove_rounded,
                  label: 'Decrease capacity',
                  onTap: onDecrease,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$capacity',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'dishes today',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _CapacityStepperButton(
                  icon: Icons.add_rounded,
                  label: 'Increase capacity',
                  onTap: onIncrease,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.homeChrome,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save Capacity'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityStepperButton extends StatelessWidget {
  const _CapacityStepperButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.homeDivider,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
