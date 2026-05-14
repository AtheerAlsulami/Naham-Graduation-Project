import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:provider/provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isLoading = true;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _startStatusChecking();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecking() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isLoading) {
        context.read<OrdersProvider>().fetchOrderById(widget.orderId);
      }
    });
  }

  Future<void> _bootstrap() async {
    final provider = context.read<OrdersProvider>();
    await provider.fetchOrderById(widget.orderId);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrdersProvider>().byId(widget.orderId);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: AppColors.homeChrome,
          foregroundColor: Colors.white,
          title: Text(
            'Track order',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : order == null
                ? _MissingOrderState(orderId: widget.orderId)
                : RefreshIndicator(
                    onRefresh: () => context.read<OrdersProvider>().fetchOrderById(widget.orderId),
                    color: AppColors.homeChrome,
                    child: _TrackingContent(order: order),
                  ),
      ),
    );
  }
}

class _MissingOrderState extends StatelessWidget {
  const _MissingOrderState({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded,
                size: 38, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(
              'Order not found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              orderId,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.order});

  final CustomerOrderModel order;

  int _stepIndex() {
    switch (order.status) {
      case CustomerOrderStatus.pendingReview:
        return 0;
      case CustomerOrderStatus.preparing:
      case CustomerOrderStatus.replacementPendingCook:
        return 1;
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
        return 2;
      case CustomerOrderStatus.awaitingCustomerConfirmation:
      case CustomerOrderStatus.issueReported:
        return 3;
      case CustomerOrderStatus.delivered:
        return 4;
      case CustomerOrderStatus.cancelled:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _stepIndex();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
      children: [
        _OrderTimelineCard(stepIndex: stepIndex),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _OrderBoxLoadingPanel(status: order.status),
        ),
        const SizedBox(height: 12),
        _TrackingActionPanel(order: order),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final cookId = order.cookId.trim();
                  if (cookId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Cook chat is unavailable for this order.'),
                      ),
                    );
                    return;
                  }

                  try {
                    final conversationId =
                        await context.read<ChatProvider>().createConversation(
                              otherUserId: cookId,
                              otherUserName: order.cookName.trim().isEmpty
                                  ? 'Cook'
                                  : order.cookName.trim(),
                              type: ChatParticipantType.cook,
                            );
                    if (!context.mounted) {
                      return;
                    }
                    final encodedConversation =
                        Uri.encodeComponent(conversationId);
                    context.go(
                      '${AppRoutes.customerHome}?tab=chat&conversation=$encodedConversation',
                    );
                  } catch (_) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to open chat with cook.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat Cook'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _OrderItemsCard(order: order),
      ],
    );
  }
}

class _TrackingActionPanel extends StatefulWidget {
  const _TrackingActionPanel({required this.order});

  final CustomerOrderModel order;

  @override
  State<_TrackingActionPanel> createState() => _TrackingActionPanelState();
}

class _TrackingActionPanelState extends State<_TrackingActionPanel> {
  bool _isBusy = false;

  Future<void> _run(
    Future<void> Function(OrdersProvider provider) action,
    String successMessage,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action(context.read<OrdersProvider>());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final actions = <Widget>[];

    // Ready for pickup OR awaiting confirmation → show Received / Not Received
    if (order.status == CustomerOrderStatus.readyForPickup ||
        order.status == CustomerOrderStatus.outForDelivery ||
        order.status == CustomerOrderStatus.awaitingCustomerConfirmation) {
      actions.addAll([
        _ActionButton(
          label: 'Order Received',
          icon: Icons.check_circle_rounded,
          filled: true,
          isBusy: _isBusy,
          onTap: () => _run(
            (provider) => provider.confirmReceived(order.id),
            'Thank you! Order receipt confirmed.',
          ),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: 'Not Received',
          icon: Icons.cancel_rounded,
          isBusy: _isBusy,
          onTap: () => _run(
            (provider) => provider.reportNotReceived(order.id),
            'Cook has been notified. They will handle the issue.',
          ),
        ),
      ]);
    }

    // Issue reported → show "Cook is handling it" and option to cancel
    if (order.status == CustomerOrderStatus.issueReported) {
      actions.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFE65100), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The cook is handling your issue. You will be notified once it\'s resolved.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Nudge cook if late
    if (order.canNudgeLate) {
      actions.add(
        _ActionButton(
          label: 'Nudge Cook',
          icon: Icons.notifications_active_outlined,
          isBusy: _isBusy,
          onTap: () => _run(
            (provider) => provider.nudgeLate(order.id),
            'Cook was notified that the order is late.',
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      final dueAt = order.deliveryDueAt;
      final text = dueAt == null
          ? 'Order status updates will appear here.'
          : 'Expected by ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';
      return _InfoPanel(text: text);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.isBusy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
    if (filled) {
      return ElevatedButton(
        onPressed: isBusy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.homeChrome,
          foregroundColor: Colors.white,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: isBusy ? null : onTap,
      child: child,
    );
  }
}

class _OrderTimelineCard extends StatelessWidget {
  const _OrderTimelineCard({required this.stepIndex});

  final int stepIndex;

  static const _labels = ['Placed', 'Cooking', 'Ready', 'Confirm', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Row(
        children: List.generate(_labels.length, (index) {
          final done = index <= stepIndex;
          final isLast = index == _labels.length - 1;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? AppColors.homeChrome
                              : const Color(0xFFE0E3E8),
                        ),
                        child: Icon(
                          done ? Icons.check : Icons.circle_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _labels[index],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                          color:
                              done ? AppColors.textPrimary : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: stepIndex > index
                        ? AppColors.homeChrome
                        : const Color(0xFFE0E3E8),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _OrderBoxLoadingPanel extends StatefulWidget {
  const _OrderBoxLoadingPanel({required this.status});

  final CustomerOrderStatus status;

  @override
  State<_OrderBoxLoadingPanel> createState() => _OrderBoxLoadingPanelState();
}

class _OrderBoxLoadingPanelState extends State<_OrderBoxLoadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _slide = Tween<double>(begin: -44, end: 44).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -12, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.status) {
      case CustomerOrderStatus.pendingReview:
        return 'Order received';
      case CustomerOrderStatus.preparing:
        return 'Preparing your order';
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
        return 'Order is ready for pickup';
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        return 'Please confirm you received the order';
      case CustomerOrderStatus.issueReported:
        return 'Cook is handling your issue';
      case CustomerOrderStatus.replacementPendingCook:
        return 'Waiting for replacement approval';
      case CustomerOrderStatus.delivered:
        return 'Order delivered';
      case CustomerOrderStatus.cancelled:
        return 'Order cancelled';
    }
  }

  String get _subtitle {
    switch (widget.status) {
      case CustomerOrderStatus.pendingReview:
        return 'Waiting for the cook to accept your order.';
      case CustomerOrderStatus.preparing:
        return 'The cook is preparing your meal.';
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
        return 'Your order is ready! Please pick it up.';
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        return 'Tap "Order Received" to confirm, or "Not Received" if there\'s an issue.';
      case CustomerOrderStatus.issueReported:
        return 'The cook has been notified and is working on a solution.';
      case CustomerOrderStatus.replacementPendingCook:
        return 'Waiting for the cook to approve the replacement.';
      case CustomerOrderStatus.delivered:
        return 'Thank you for your order!';
      case CustomerOrderStatus.cancelled:
        return 'This order has been cancelled.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3F6FA),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 20,
                      left: 34,
                      right: 34,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7EAF0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Transform.translate(
                        offset: Offset(_slide.value, _bounce.value),
                        child: child,
                      ),
                    ),
                    Positioned(
                      top: 20,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final phase = (_controller.value + index * 0.18) % 1;
                          return Opacity(
                            opacity: 0.35 + (phase * 0.65),
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: const BoxDecoration(
                                color: AppColors.homeChrome,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          );
        },
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: AppColors.homeChrome,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.homeChrome.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context) {
    // Use actual items list; if empty, create a single item from the order's primary fields
    final displayItems = order.items.isNotEmpty
        ? order.items
        : [
            CustomerOrderItemModel(
              dishId: order.dishId,
              dishName: order.dishName.isNotEmpty ? order.dishName : 'Item',
              imageUrl: order.imageUrl,
              quantity: order.itemCount <= 0 ? 1 : order.itemCount,
              price: order.price,
            ),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...displayItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.dishName}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${item.total.toStringAsFixed(2)} SAR',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${order.totalAmount.toStringAsFixed(2)} SAR',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (order.cookEarnings > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cook Earnings',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${order.cookEarnings.toStringAsFixed(2)} SAR',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
