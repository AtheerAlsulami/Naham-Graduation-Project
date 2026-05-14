import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:provider/provider.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  OrdersFilter _selectedFilter = OrdersFilter.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
      context.read<DishProvider>().loadCustomerDishes(limit: 250);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersProvider>().ordersFor(_selectedFilter);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<OrdersProvider>().loadOrders(force: true);
      },
      color: AppColors.homeChrome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _OrdersFilterChip(
                  label: 'Active',
                  isActive: _selectedFilter == OrdersFilter.active,
                  onTap: () =>
                      setState(() => _selectedFilter = OrdersFilter.active),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrdersFilterChip(
                  label: 'Completed',
                  isActive: _selectedFilter == OrdersFilter.completed,
                  onTap: () =>
                      setState(() => _selectedFilter = OrdersFilter.completed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrdersFilterChip(
                  label: 'Cancelled',
                  isActive: _selectedFilter == OrdersFilter.cancelled,
                  onTap: () =>
                      setState(() => _selectedFilter = OrdersFilter.cancelled),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (orders.isEmpty)
            _OrdersEmptyState(filter: _selectedFilter)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderCard(
                  order: order,
                  onTrackTap: () {
                    if (order.status == CustomerOrderStatus.pendingReview) {
                      context
                          .push('${AppRoutes.orderWaitingApproval}/${order.id}');
                    } else {
                      context.push('${AppRoutes.orderTracking}/${order.id}');
                    }
                  },
                  onContactTap: () => _openCookChat(order),
                  onCancelTap: order.status == CustomerOrderStatus.pendingReview
                      ? () => _cancelPreparingOrder(order)
                      : null,
                  onReorderTap: order.status == CustomerOrderStatus.cancelled
                      ? () => _reorderOrder(order)
                      : null,
                  onRateTap: order.status == CustomerOrderStatus.delivered
                      ? () => _showRateSheet(order)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openCookChat(CustomerOrderModel order) async {
    final cookId = order.cookId.trim();
    if (cookId.isEmpty) {
      _showContactSheet(order);
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
      if (!mounted) {
        return;
      }

      final encodedConversation = Uri.encodeComponent(conversationId);
      final encodedOrderImage = Uri.encodeComponent(order.imageUrl);
      context.go(
        '${AppRoutes.customerHome}?tab=chat&conversation=$encodedConversation&orderImage=$encodedOrderImage',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showContactSheet(order);
    }
  }

  void _showContactSheet(CustomerOrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
              const SizedBox(height: 18),
              Text(
                'Contact ${order.contactRole ?? 'support'}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.homeMintSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.homeCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.contactName ?? 'Support',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.contactPhone ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: order.contactPhone ?? ''),
                    );
                    if (!mounted) return;
                    navigator.pop();
                    _showSnack('${order.contactPhone} copied to clipboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.homeChrome,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Copy phone number',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Future<void> _cancelPreparingOrder(CustomerOrderModel order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Cancel order?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will move ${order.dishName} to the Cancelled tab.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel order'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) return;

    await context.read<OrdersProvider>().cancelPreparingOrder(order.id);
    setState(() {
      _selectedFilter = OrdersFilter.cancelled;
    });
    _showSnack('${order.dishName} moved to cancelled orders');
  }

  Future<void> _showRateSheet(CustomerOrderModel order) async {
    var selectedCookRating = order.cookRating ?? order.rating ?? 5;
    var selectedServiceRating = order.serviceRating ?? order.rating ?? 5;
    final commentController = TextEditingController(text: order.reviewComment);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.homeDivider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Rate ${order.dishName}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RatingStars(
                    label: 'Cook',
                    value: selectedCookRating,
                    onChanged: (value) {
                      setModalState(() => selectedCookRating = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _RatingStars(
                    label: 'Service',
                    value: selectedServiceRating,
                    onChanged: (value) {
                      setModalState(() => selectedServiceRating = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a short review',
                      filled: true,
                      fillColor: const Color(0xFFF5F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.read<OrdersProvider>().submitRating(
                              order.id,
                              cookRating: selectedCookRating,
                              serviceRating: selectedServiceRating,
                              reviewComment: commentController.text.trim(),
                            );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.homeChrome,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Submit rating',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
    if (!mounted) return;
    _showSnack('Thanks for rating ${order.dishName}');
  }

  Future<void> _reorderOrder(CustomerOrderModel order) async {
    final cart = context.read<CartProvider>();
    final dishProvider = context.read<DishProvider>();
    DishModel? dish = dishProvider.findDishById(order.dishId);
    if (dish == null && order.items.isNotEmpty) {
      dish = dishProvider.findDishById(order.items.first.dishId);
    }
    if (dish == null) {
      _showSnack('Dish is no longer available');
      return;
    }

    if (cart.items.isNotEmpty && cart.currentCookId != dish.cookId) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Replace current cart?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Your cart has dishes from another cook. Reordering ${order.dishName} will clear it first.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );

      if (shouldReplace != true || !mounted) return;
      cart.clearCart();
    }

    cart.addItem(dish, 1);
    if (!mounted) return;
    _showSnack('${order.dishName} added to cart');
    context.push(AppRoutes.cart);
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

class _RatingStars extends StatelessWidget {
  const _RatingStars({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: () => onChanged(starValue),
                tooltip: 'Rate $starValue stars',
                icon: Icon(
                  starValue <= value
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 30,
                  color: AppColors.warning,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _OrdersFilterChip extends StatelessWidget {
  const _OrdersFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label orders filter',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.homeDeliveryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                isActive ? null : Border.all(color: AppColors.homeCardBorder),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.homeDeliveryGreen,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.filter});

  final OrdersFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      OrdersFilter.active => 'No active orders',
      OrdersFilter.completed => 'No completed orders',
      OrdersFilter.cancelled => 'No cancelled orders',
    };

    final message = switch (filter) {
      OrdersFilter.active =>
        'Any order in progress will appear here with live actions.',
      OrdersFilter.completed =>
        'Delivered orders will appear here for rating and review.',
      OrdersFilter.cancelled =>
        'Cancelled orders will appear here with reorder actions.',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.homeCardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.homeMintSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTrackTap,
    this.onContactTap,
    this.onCancelTap,
    this.onReorderTap,
    this.onRateTap,
  });

  final CustomerOrderModel order;
  final VoidCallback onTrackTap;
  final VoidCallback? onContactTap;
  final VoidCallback? onCancelTap;
  final VoidCallback? onReorderTap;
  final VoidCallback? onRateTap;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _statusThemeFor(order.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusTheme.chipBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusTheme.icon,
                      size: 13,
                      color: statusTheme.primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusTheme.label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusTheme.primaryColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                order.displayId,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFABB3BF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: order.imageUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 54,
                    height: 54,
                    color: AppColors.homeDivider,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 54,
                    height: 54,
                    color: AppColors.homeDivider,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.dishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      order.cookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.price.toStringAsFixed(0)} SAR',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusTheme.infoBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  order.infoLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: statusTheme.infoLabelColor,
                  ),
                ),
                const Spacer(),
                Text(
                  order.infoValue,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusTheme.infoValueColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    switch (order.status) {
      case CustomerOrderStatus.pendingReview:
        return _PrimaryActionButton(
          label: 'Waiting for cook approval',
          onTap: onTrackTap,
        );
      case CustomerOrderStatus.preparing:
      case CustomerOrderStatus.readyForPickup:
      case CustomerOrderStatus.outForDelivery:
      case CustomerOrderStatus.awaitingCustomerConfirmation:
      case CustomerOrderStatus.issueReported:
      case CustomerOrderStatus.replacementPendingCook:
        return Row(
          children: [
            Expanded(
              child: _PrimaryActionButton(
                label: 'Track Order',
                onTap: onTrackTap,
              ),
            ),
          ],
        );
      case CustomerOrderStatus.delivered:
        return _PrimaryActionButton(
          label: order.isRated ? 'Rated ${order.rating}/5' : 'Rate Us',
          onTap: onRateTap!,
        );
      case CustomerOrderStatus.cancelled:
        return _PrimaryActionButton(
          label: 'Reorder',
          onTap: onReorderTap!,
        );
    }
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.homeChrome,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

_OrderStatusTheme _statusThemeFor(CustomerOrderStatus status) {
  switch (status) {
    case CustomerOrderStatus.pendingReview:
      return const _OrderStatusTheme(
        label: 'Pending Review',
        icon: Icons.hourglass_top_rounded,
        primaryColor: Color(0xFF9A7C2D),
        chipBackground: Color(0xFFFFF8E8),
        infoBackground: Color(0xFFFFF4D6),
        infoLabelColor: Color(0xFF977D35),
        infoValueColor: Color(0xFF7E691F),
        borderColor: Color(0xFFEFE3B3),
      );
    case CustomerOrderStatus.readyForPickup:
    case CustomerOrderStatus.outForDelivery:
      return const _OrderStatusTheme(
        label: 'Ready for Pickup',
        icon: Icons.storefront_rounded,
        primaryColor: Color(0xFF4C8F63),
        chipBackground: Color(0xFFE9F9EE),
        infoBackground: Color(0xFFD6F5E0),
        infoLabelColor: Color(0xFF658871),
        infoValueColor: Color(0xFF3E8A58),
        borderColor: Color(0xFFCEEAD5),
      );
    case CustomerOrderStatus.preparing:
      return const _OrderStatusTheme(
        label: 'Preparing',
        icon: Icons.restaurant_rounded,
        primaryColor: Color(0xFF4F8B62),
        chipBackground: Color(0xFFE9F9EE),
        infoBackground: Color(0xFFD6F5E0),
        infoLabelColor: Color(0xFF658871),
        infoValueColor: Color(0xFF3E8A58),
        borderColor: Color(0xFFCEEAD5),
      );
    case CustomerOrderStatus.awaitingCustomerConfirmation:
      return const _OrderStatusTheme(
        label: 'Confirm Receipt',
        icon: Icons.fact_check_rounded,
        primaryColor: Color(0xFF4F6DC7),
        chipBackground: Color(0xFFEAF0FF),
        infoBackground: Color(0xFFE6EDFF),
        infoLabelColor: Color(0xFF65749A),
        infoValueColor: Color(0xFF3D58AF),
        borderColor: Color(0xFFD4DFFF),
      );
    case CustomerOrderStatus.issueReported:
      return const _OrderStatusTheme(
        label: 'Issue Reported',
        icon: Icons.report_problem_rounded,
        primaryColor: Color(0xFFD08224),
        chipBackground: Color(0xFFFFF3E4),
        infoBackground: Color(0xFFFFE9C7),
        infoLabelColor: Color(0xFF9C6E3A),
        infoValueColor: Color(0xFFC2761A),
        borderColor: Color(0xFFF0D3A7),
      );
    case CustomerOrderStatus.replacementPendingCook:
      return const _OrderStatusTheme(
        label: 'Replacement Pending',
        icon: Icons.swap_horiz_rounded,
        primaryColor: Color(0xFF8D50C8),
        chipBackground: Color(0xFFF2E8FF),
        infoBackground: Color(0xFFEBDFFF),
        infoLabelColor: Color(0xFF80649D),
        infoValueColor: Color(0xFF7448AA),
        borderColor: Color(0xFFE2D1F5),
      );
    case CustomerOrderStatus.delivered:
      return const _OrderStatusTheme(
        label: 'Delivered',
        icon: Icons.check_circle_rounded,
        primaryColor: Color(0xFF77C68F),
        chipBackground: Color(0xFFEAFBEF),
        infoBackground: Color(0xFFF3FBF5),
        infoLabelColor: Color(0xFF7D9284),
        infoValueColor: Color(0xFF4EA66A),
        borderColor: Color(0xFFD8EFD9),
      );
    case CustomerOrderStatus.cancelled:
      return const _OrderStatusTheme(
        label: 'Cancelled',
        icon: Icons.cancel_rounded,
        primaryColor: Color(0xFFFF6E76),
        chipBackground: Color(0xFFFFEEF0),
        infoBackground: Color(0xFFFFE1E4),
        infoLabelColor: Color(0xFFE76A73),
        infoValueColor: Color(0xFFE76A73),
        borderColor: Color(0xFFF3D9DC),
      );
  }
}

class _OrderStatusTheme {
  const _OrderStatusTheme({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.chipBackground,
    required this.infoBackground,
    required this.infoLabelColor,
    required this.infoValueColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color chipBackground;
  final Color infoBackground;
  final Color infoLabelColor;
  final Color infoValueColor;
  final Color borderColor;
}
