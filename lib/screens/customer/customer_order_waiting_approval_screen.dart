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

class CustomerOrderWaitingApprovalScreen extends StatefulWidget {
  const CustomerOrderWaitingApprovalScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<CustomerOrderWaitingApprovalScreen> createState() =>
      _CustomerOrderWaitingApprovalScreenState();
}

class _CustomerOrderWaitingApprovalScreenState
    extends State<CustomerOrderWaitingApprovalScreen> {
  bool _isLoading = true;
  CustomerOrderModel? _order;
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _startStatusChecking();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final provider = context.read<OrdersProvider>();
    final order = await provider.fetchOrderById(widget.orderId);
    if (!mounted) return;

    setState(() {
      _order = order;
      _isLoading = false;
    });

    if (order != null && order.status != CustomerOrderStatus.pendingReview) {
      _navigateToTracking();
    }
  }

  void _startStatusChecking() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadOrder();
    });
  }

  void _navigateToTracking() {
    _statusCheckTimer?.cancel();
    if (!mounted) return;
    context.go('${AppRoutes.orderTracking}/${widget.orderId}');
  }

  Future<void> _checkStatus() async {
    await _loadOrder();
  }

  Duration get _remainingApprovalTime {
    final expiresAt = _order?.approvalExpiresAt;
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _approvalExpired =>
      _order?.approvalExpiresAt != null &&
      _remainingApprovalTime == Duration.zero;

  String get _approvalCountdownLabel {
    final remaining = _remainingApprovalTime;
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _cancelOrder() async {
    await context.read<OrdersProvider>().cancelPreparingOrder(widget.orderId);
    if (!mounted) return;
    context.go(AppRoutes.customerHome);
  }

  Future<void> _openCookChat() async {
    final order = _order;
    if (order == null || order.cookId.trim().isEmpty) return;
    try {
      final conversationId = await context.read<ChatProvider>().createConversation(
            otherUserId: order.cookId,
            otherUserName: order.cookName.trim().isEmpty ? 'Cook' : order.cookName,
            type: ChatParticipantType.cook,
          );
      if (!mounted) return;
      context.go(
        '${AppRoutes.customerHome}?tab=chat&conversation=${Uri.encodeComponent(conversationId)}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open chat with cook.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.homeChrome,
          foregroundColor: Colors.white,
          title: Text(
            'Waiting for Cook Approval',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _order == null
                ? const Center(child: Text('Order not found'))
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 100,
                          color: AppColors.homeChrome,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Waiting for Cook Approval',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _approvalExpired
                              ? 'The approval window has ended. You can cancel this order or message the cook.'
                              : 'Your order has been sent to the cook. We\'re waiting for their approval to start preparing your meal.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _approvalExpired
                              ? 'Approval time expired'
                              : _order?.approvalExpiresAt == null
                                  ? 'Waiting for response'
                                  : 'Time left: $_approvalCountdownLabel',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _approvalExpired
                                ? AppColors.error
                                : AppColors.homeChrome,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_approvalExpired) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _cancelOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Cancel Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openCookChat,
                              icon: const Icon(Icons.chat_bubble_outline_rounded),
                              label: const Text('Chat Cook'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ElevatedButton(
                          onPressed: _checkStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.homeChrome,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Check Status',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.customerHome),
                          child: Text(
                            'Back to Home',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: AppColors.homeChrome,
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
