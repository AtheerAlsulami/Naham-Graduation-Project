import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:provider/provider.dart';

class CookOrdersScreen extends StatefulWidget {
  const CookOrdersScreen({super.key});

  @override
  State<CookOrdersScreen> createState() => _CookOrdersScreenState();
}

class _CookOrdersScreenState extends State<CookOrdersScreen> {
  _CookOrdersTab _selectedTab = _CookOrdersTab.newOrders;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final allOrders = _sourceOrders(ordersProvider.orders);
    final visibleOrders = _ordersForTab(_selectedTab, allOrders);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        body: Column(
          children: [
            _OrdersHeader(
              selectedTab: _selectedTab,
              newCount: _countByStatus(_CookOrderStatus.newOrder, allOrders),
              activeCount: _countByStatus(_CookOrderStatus.active, allOrders),
              completedCount: _countByStatus(_CookOrderStatus.completed, allOrders),
              onTabChanged: (tab) => setState(() => _selectedTab = tab),
            ),
            Expanded(
              child: ordersProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleOrders.isEmpty
                  ? _OrdersEmptyState(tab: _selectedTab)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      itemCount: visibleOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final order = visibleOrders[index];
                        return _buildOrderCard(order);
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 1,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == 1) return;
    if (index == 0) {
      context.go(AppRoutes.cookReels);
      return;
    }
    if (index == 2) {
      context.go(AppRoutes.cookDashboard);
      return;
    }
    if (index == 5) {
      context.go(AppRoutes.cookPublicProfile);
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

  Widget _buildOrderCard(_CookOrder order) {
    return switch (order.status) {
      _CookOrderStatus.newOrder => _NewOrderCard(
          order: order,
          placedAgoLabel: _placedAgo(order.placedAt),
          onAcceptTap: () => _acceptOrder(order),
          onRejectTap: () => _rejectOrder(order),
        ),
      _CookOrderStatus.active => _ActiveOrderCard(
          order: order,
          readyInLabel: _readyInLabel(order),
          readyAtLabel: _clockLabel(_readyAt(order)),
          statusLabel: _activeStatusLabel(order),
          statusColor: _activeStatusColor(order),
          statusTextColor: _activeStatusTextColor(order),
          onViewTap: () => _showOrderDetails(order),
        ),
      _CookOrderStatus.completed => _CompletedOrderCard(
          order: order,
          completedAtLabel: _clockLabel(order.completedAt ?? order.placedAt),
        ),
    };
  }

  List<_CookOrder> _sourceOrders(List<CustomerOrderModel> source) {
    final now = DateTime.now();
    return source.map((order) {
      final mappedStatus = switch (order.status) {
        CustomerOrderStatus.pendingReview => _CookOrderStatus.newOrder,
        CustomerOrderStatus.preparing => _CookOrderStatus.active,
        CustomerOrderStatus.readyForPickup => _CookOrderStatus.active,
        CustomerOrderStatus.outForDelivery => _CookOrderStatus.active,
        CustomerOrderStatus.awaitingCustomerConfirmation =>
          _CookOrderStatus.active,
        CustomerOrderStatus.issueReported => _CookOrderStatus.active,
        CustomerOrderStatus.replacementPendingCook => _CookOrderStatus.active,
        CustomerOrderStatus.delivered => _CookOrderStatus.completed,
        CustomerOrderStatus.cancelled => _CookOrderStatus.completed,
      };

      final itemModels = order.items.isNotEmpty
          ? order.items
          : [
              CustomerOrderItemModel(
                dishId: order.dishId,
                dishName: order.dishName,
                imageUrl: order.imageUrl,
                quantity: order.itemCount <= 0 ? 1 : order.itemCount,
                price: order.price,
              ),
            ];

      return _CookOrder(
        id: order.id,
        number: order.displayId.isNotEmpty
            ? order.displayId.replaceAll('#', '')
            : order.id,
        customerName: order.customerName.isNotEmpty
            ? order.customerName
            : 'Customer',
        items: itemModels
            .map(
              (item) => _CookOrderItem(
                name: item.dishName,
                quantity: item.quantity,
              ),
            )
            .toList(growable: false),
        earningsSar: order.cookEarnings > 0
            ? order.cookEarnings
            : (order.totalAmount > 0 ? order.totalAmount * 0.9 : order.price),
        suggestedPrep: Duration(minutes: order.prepEstimateMinutes),
        placedAt: order.createdAt ?? now,
        acceptedAt: order.acceptedAt,
        completedAt: order.deliveredAt ?? order.cancelledAt,
        deliveryDueAt: order.deliveryDueAt,
        note: order.note.isEmpty ? null : order.note,
        status: mappedStatus,
        rawStatus: order.status,
        issueReason: order.issueReason,
      );
    }).toList(growable: false);
  }

  List<_CookOrder> _ordersForTab(_CookOrdersTab tab, List<_CookOrder> orders) {
    final status = _statusForTab(tab);
    final items = orders.where((order) => order.status == status).toList();

    items.sort((a, b) {
      return switch (status) {
        _CookOrderStatus.newOrder => b.placedAt.compareTo(a.placedAt),
        _CookOrderStatus.active => _readyAt(a).compareTo(_readyAt(b)),
        _CookOrderStatus.completed => (b.completedAt ?? b.placedAt).compareTo(
            a.completedAt ?? a.placedAt,
          ),
      };
    });

    return items;
  }

  _CookOrderStatus _statusForTab(_CookOrdersTab tab) {
    return switch (tab) {
      _CookOrdersTab.newOrders => _CookOrderStatus.newOrder,
      _CookOrdersTab.activeOrders => _CookOrderStatus.active,
      _CookOrdersTab.completedOrders => _CookOrderStatus.completed,
    };
  }

  int _countByStatus(_CookOrderStatus status, List<_CookOrder> orders) {
    return orders.where((order) => order.status == status).length;
  }

  DateTime _readyAt(_CookOrder order) {
    if (order.rawStatus == CustomerOrderStatus.readyForPickup ||
        order.rawStatus == CustomerOrderStatus.outForDelivery ||
        order.rawStatus == CustomerOrderStatus.awaitingCustomerConfirmation) {
      return order.deliveryDueAt ?? DateTime.now();
    }
    final accepted = order.acceptedAt ?? order.placedAt;
    return accepted.add(order.suggestedPrep);
  }

  int _remainingMinutes(_CookOrder order) {
    final remainingSeconds = _readyAt(order).difference(DateTime.now()).inSeconds;
    if (remainingSeconds <= 0) return 0;
    return (remainingSeconds / 60).ceil();
  }

  String _readyInLabel(_CookOrder order) {
    final minutes = _remainingMinutes(order);
    if (minutes <= 0) return 'Ready now';
    if (minutes == 1) return 'Ready in 1 min';
    return 'Ready in $minutes min';
  }

  String _activeStatusLabel(_CookOrder order) {
    switch (order.rawStatus) {
      case CustomerOrderStatus.readyForPickup:
        return 'Ready for pickup';
      case CustomerOrderStatus.outForDelivery:
        return 'Ready for pickup';
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        return 'Customer confirmed';
      case CustomerOrderStatus.issueReported:
        return '⚠️ Not received';
      case CustomerOrderStatus.replacementPendingCook:
        return 'Replacement pending';
      case CustomerOrderStatus.pendingReview:
      case CustomerOrderStatus.preparing:
      case CustomerOrderStatus.delivered:
      case CustomerOrderStatus.cancelled:
        break;
    }
    final minutes = _remainingMinutes(order);
    if (minutes == 0) return 'Ready';
    if (minutes <= 5) return 'Almost Ready';
    return 'Cooking';
  }

  Color _activeStatusColor(_CookOrder order) {
    final minutes = _remainingMinutes(order);
    if (minutes == 0) return const Color(0xFFE8F8EE);
    if (minutes <= 5) return const Color(0xFFFFF1D5);
    return const Color(0xFFEBDFFF);
  }

  Color _activeStatusTextColor(_CookOrder order) {
    final minutes = _remainingMinutes(order);
    if (minutes == 0) return const Color(0xFF249B5A);
    if (minutes <= 5) return const Color(0xFFC78600);
    return const Color(0xFF8D50C8);
  }

  String _placedAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes <= 0) return 'just now';
    if (diff.inMinutes == 1) return '1 minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String _clockLabel(DateTime value) {
    return DateFormat('h:mm a').format(value);
  }

  Future<void> _acceptOrder(_CookOrder order) async {
    await context.read<OrdersProvider>().moveToInProgress(order.id);
    if (!mounted) return;
    setState(() {
      _selectedTab = _CookOrdersTab.activeOrders;
    });
    _showSnack('Order ${order.number} accepted');
  }

  Future<void> _rejectOrder(_CookOrder order) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Reject order #${order.number}?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'The customer will be notified that this order was declined.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true || !mounted) {
      return;
    }

    await context.read<OrdersProvider>().rejectOrder(order.id);
    if (!mounted) return;
    _showSnack('Order ${order.number} rejected');
  }

  void _showOrderDetails(_CookOrder order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _OrderDetailsSheet(
          order: order,
          statusLabel: _activeStatusLabel(order),
          readyInLabel: _readyInLabel(order),
          readyAtLabel: _clockLabel(_readyAt(order)),
          completeButtonLabel: _nextActionLabel(order),
          onMarkCompleted: _hasNextAction(order)
              ? () {
                  Navigator.of(context).pop();
                  _advanceOrder(order);
                }
              : null,
          onReportIssue: _canReportIssue(order)
              ? () {
                  Navigator.of(context).pop();
                  _reportIssue(order);
                }
              : null,
        );
      },
    );
  }

  String _nextActionLabel(_CookOrder order) {
    switch (order.rawStatus) {
      case CustomerOrderStatus.preparing:
        return 'Mark Ready for Pickup';
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
        return 'Waiting for customer';
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        return 'Finish Order';
      case CustomerOrderStatus.issueReported:
        return 'Resolve Issue';
      case CustomerOrderStatus.replacementPendingCook:
        return 'Approve Replacement';
      case CustomerOrderStatus.pendingReview:
      case CustomerOrderStatus.delivered:
      case CustomerOrderStatus.cancelled:
        return 'Waiting';
    }
  }

  bool _hasNextAction(_CookOrder order) {
    return order.rawStatus == CustomerOrderStatus.preparing ||
        order.rawStatus == CustomerOrderStatus.awaitingCustomerConfirmation ||
        order.rawStatus == CustomerOrderStatus.issueReported ||
        order.rawStatus == CustomerOrderStatus.replacementPendingCook;
  }

  bool _canReportIssue(_CookOrder order) {
    return order.rawStatus == CustomerOrderStatus.preparing ||
        order.rawStatus == CustomerOrderStatus.readyForPickup ||
        order.rawStatus == CustomerOrderStatus.outForDelivery ||
        order.rawStatus == CustomerOrderStatus.awaitingCustomerConfirmation;
  }

  Future<void> _advanceOrder(_CookOrder order) async {
    final provider = context.read<OrdersProvider>();
    switch (order.rawStatus) {
      case CustomerOrderStatus.preparing:
        await provider.markReadyForPickup(order.id);
        break;
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        await provider.finishOrder(order.id);
        break;
      case CustomerOrderStatus.issueReported:
        await provider.resolveIssue(order.id);
        break;
      case CustomerOrderStatus.replacementPendingCook:
        await provider.approveReplacement(order.id);
        break;
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
      case CustomerOrderStatus.pendingReview:
      case CustomerOrderStatus.delivered:
      case CustomerOrderStatus.cancelled:
        return;
    }
    if (!mounted) return;
    _showSnack('Order ${order.number} updated');
  }

  Future<void> _reportIssue(_CookOrder order) async {
    final controller = TextEditingController();
    final issue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Report order issue',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe what happened',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (issue == null || issue.trim().isEmpty || !mounted) return;
    await context
        .read<OrdersProvider>()
        .reportIssue(order.id, issueReason: issue.trim());
    if (!mounted) return;
    _showSnack('Issue reported for order ${order.number}');
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

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.selectedTab,
    required this.newCount,
    required this.activeCount,
    required this.completedCount,
    required this.onTabChanged,
  });

  final _CookOrdersTab selectedTab;
  final int newCount;
  final int activeCount;
  final int completedCount;
  final ValueChanged<_CookOrdersTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(18, topPadding + 13, 18, 14),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Orders',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OrdersTabButton(
                icon: Icons.auto_awesome_rounded,
                label: 'New',
                count: newCount,
                isSelected: selectedTab == _CookOrdersTab.newOrders,
                onTap: () => onTabChanged(_CookOrdersTab.newOrders),
              ),
              const SizedBox(width: 8),
              _OrdersTabButton(
                icon: Icons.access_time_rounded,
                label: 'Active',
                count: activeCount,
                isSelected: selectedTab == _CookOrdersTab.activeOrders,
                onTap: () => onTabChanged(_CookOrdersTab.activeOrders),
              ),
              const SizedBox(width: 8),
              _OrdersTabButton(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed',
                count: completedCount,
                isSelected: selectedTab == _CookOrdersTab.completedOrders,
                onTap: () => onTabChanged(_CookOrdersTab.completedOrders),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdersTabButton extends StatelessWidget {
  const _OrdersTabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.authButtonEnd;
    final inactiveColor = Colors.white.withValues(alpha: 0.68);

    return SizedBox(
      width: 96,
      height: 66,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15.5,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? activeColor : inactiveColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewOrderCard extends StatelessWidget {
  const _NewOrderCard({
    required this.order,
    required this.placedAgoLabel,
    required this.onAcceptTap,
    required this.onRejectTap,
  });

  final _CookOrder order;
  final String placedAgoLabel;
  final VoidCallback onAcceptTap;
  final VoidCallback onRejectTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: _orderCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${order.number}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const _StatusBadge(
                label: 'New',
                color: Color(0xFFE5EFFF),
                textColor: Color(0xFF3D7DFF),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            order.customerName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _OrderInfoLine(label: 'Items', value: order.itemsSummary),
          _OrderInfoLine(
            label: 'Estimated earnings',
            value: '${order.earningsSar.toStringAsFixed(2)} SAR',
            valueColor: const Color(0xFF18A958),
            valueWeight: FontWeight.w600,
          ),
          _OrderInfoLine(
            label: 'Suggested prep time',
            value: '${order.suggestedPrep.inMinutes} min',
          ),
          _OrderInfoLine(
            label: 'Placed',
            value: placedAgoLabel,
            valueColor: const Color(0xFFFF6E4C),
            valueWeight: FontWeight.w600,
          ),
          if (order.note != null && order.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${order.note}',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: const Color(0xFF8A6E2F),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.homeDivider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAcceptTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0FA958),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(
                    'Accept',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRejectTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5757),
                    side: const BorderSide(color: Color(0xFFFFB7B7)),
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    'Reject',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.order,
    required this.readyInLabel,
    required this.readyAtLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusTextColor,
    required this.onViewTap,
  });

  final _CookOrder order;
  final String readyInLabel;
  final String readyAtLabel;
  final String statusLabel;
  final Color statusColor;
  final Color statusTextColor;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: _orderCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.number}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.earningsSar.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3CB463),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    textColor: statusTextColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.itemsSummary,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.alarm_rounded,
                size: 16,
                color: Color(0xFFFF6C55),
              ),
              const SizedBox(width: 6),
              Text(
                readyInLabel,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6C55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Est. ready: $readyAtLabel',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF8992A2),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: OutlinedButton(
              onPressed: onViewTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF707A89),
                side: const BorderSide(color: Color(0xFFE0E4EA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Icon(Icons.remove_red_eye_outlined, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  const _CompletedOrderCard({
    required this.order,
    required this.completedAtLabel,
  });

  final _CookOrder order;
  final String completedAtLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: _orderCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.number}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.earningsSar.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3CB463),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _StatusBadge(
                    label: 'Completed',
                    color: Color(0xFFECEFF4),
                    textColor: Color(0xFF6A7483),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.itemsSummary,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Completed: $completedAtLabel',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF8A93A4),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({
    required this.order,
    required this.statusLabel,
    required this.readyInLabel,
    required this.readyAtLabel,
    required this.completeButtonLabel,
    required this.onMarkCompleted,
    this.onReportIssue,
  });

  final _CookOrder order;
  final String statusLabel;
  final String readyInLabel;
  final String readyAtLabel;
  final String completeButtonLabel;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onReportIssue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.homeDivider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Order #${order.number}',
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.customerName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _OrderInfoLine(label: 'Items', value: order.itemsSummary),
            _OrderInfoLine(
              label: 'Earnings',
              value: '${order.earningsSar.toStringAsFixed(2)} SAR',
              valueColor: const Color(0xFF19A758),
              valueWeight: FontWeight.w600,
            ),
            _OrderInfoLine(label: 'Status', value: statusLabel),
            _OrderInfoLine(label: 'Ready in', value: readyInLabel),
            _OrderInfoLine(label: 'Estimated ready', value: readyAtLabel),
            if (order.note != null && order.note!.trim().isNotEmpty)
              _OrderInfoLine(label: 'Customer note', value: order.note!),
            if (order.issueReason.trim().isNotEmpty)
              _OrderInfoLine(label: 'Issue', value: order.issueReason),
            if (onMarkCompleted != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onMarkCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0FA958),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(
                    completeButtonLabel,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (onReportIssue != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReportIssue,
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(
                    'Report Issue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderInfoLine extends StatelessWidget {
  const _OrderInfoLine({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.valueWeight = FontWeight.w500,
  });

  final String label;
  final String value;
  final Color valueColor;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: valueColor,
                fontWeight: valueWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.tab});

  final _CookOrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      _CookOrdersTab.newOrders => 'No new orders',
      _CookOrdersTab.activeOrders => 'No active orders',
      _CookOrdersTab.completedOrders => 'No completed orders',
    };

    final subtitle = switch (tab) {
      _CookOrdersTab.newOrders => 'Incoming orders will appear here.',
      _CookOrdersTab.activeOrders => 'Accepted orders in progress will appear here.',
      _CookOrdersTab.completedOrders => 'Delivered orders will appear here.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFFECE3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 30,
                color: AppColors.authButtonEnd,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookOrder {
  const _CookOrder({
    required this.id,
    required this.number,
    required this.customerName,
    required this.items,
    required this.earningsSar,
    required this.suggestedPrep,
    required this.placedAt,
    required this.status,
    required this.rawStatus,
    this.acceptedAt,
    this.completedAt,
    this.deliveryDueAt,
    this.issueReason = '',
    this.note,
  });

  final String id;
  final String number;
  final String customerName;
  final List<_CookOrderItem> items;
  final double earningsSar;
  final Duration suggestedPrep;
  final DateTime placedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? deliveryDueAt;
  final String? note;
  final _CookOrderStatus status;
  final CustomerOrderStatus rawStatus;
  final String issueReason;

  String get itemsSummary {
    return items.map((item) => '${item.quantity}x ${item.name}').join(', ');
  }

  _CookOrder copyWith({
    String? id,
    String? number,
    String? customerName,
    List<_CookOrderItem>? items,
    double? earningsSar,
    Duration? suggestedPrep,
    DateTime? placedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? deliveryDueAt,
    String? note,
    _CookOrderStatus? status,
    CustomerOrderStatus? rawStatus,
    String? issueReason,
  }) {
    return _CookOrder(
      id: id ?? this.id,
      number: number ?? this.number,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      earningsSar: earningsSar ?? this.earningsSar,
      suggestedPrep: suggestedPrep ?? this.suggestedPrep,
      placedAt: placedAt ?? this.placedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      deliveryDueAt: deliveryDueAt ?? this.deliveryDueAt,
      note: note ?? this.note,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      issueReason: issueReason ?? this.issueReason,
    );
  }
}

class _CookOrderItem {
  const _CookOrderItem({
    required this.name,
    required this.quantity,
  });

  final String name;
  final int quantity;
}

enum _CookOrdersTab {
  newOrders,
  activeOrders,
  completedOrders,
}

enum _CookOrderStatus {
  newOrder,
  active,
  completed,
}

const BoxDecoration _orderCardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(13)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E5EA))),
  boxShadow: [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ],
);
