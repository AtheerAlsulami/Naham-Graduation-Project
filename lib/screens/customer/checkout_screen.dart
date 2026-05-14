import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _promoController = TextEditingController();

  double _discount = 0;
  String _paymentId = 'credit';

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _Header(title: 'Checkout', onBackTap: () => _goBack(context)),
            Expanded(
              child: cart.items.isEmpty
                  ? const _EmptyCheckout()
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        _AddressSection(
                          onChangeTap: () {},
                        ),
                        _PromoSection(
                          controller: _promoController,
                          discount: _discount,
                          onApplyTap: _applyPromoCode,
                          onCodeTap: (code) {
                            _promoController.text = code;
                            _applyPromoCode();
                          },
                        ),
                        _SummaryBox(
                          subtotal: cart.subtotal,
                          discount: _discount,
                        ),
                        const SizedBox(height: 96),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: cart.items.isEmpty
            ? null
            : _BottomPayBar(
                total: _total(cart),
                onTap: () => _showPaymentSheet(cart),
              ),
      ),
    );
  }

  double _total(CartProvider cart) {
    final total = cart.total - _discount;
    return total < 0 ? 0 : total;
  }

  String _normalizeRegion(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return AppConstants.saudiRegions.contains(trimmed) ? trimmed : '';
  }

  void _showRegionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _validateRegionForOrder(CartProvider cart) async {
    final customerRegion =
        _normalizeRegion(context.read<AuthProvider>().currentUser?.address);
    if (customerRegion.isEmpty) {
      _showRegionError(
        'Select your region in your profile before placing an order.',
      );
      return false;
    }

    if (cart.items.isEmpty) {
      return true;
    }

    final cookId = cart.currentCookId ?? cart.items.first.dish.cookId;
    final cookProvider = context.read<CookProvider>();
    if (cookProvider.cooks.isEmpty) {
      await cookProvider.loadCooks(force: true);
    }
    if (!mounted) return false;

    final matchingCooks =
        cookProvider.cooks.where((cook) => cook.id == cookId).toList();
    if (matchingCooks.isEmpty) {
      _showRegionError(
        'Unable to verify the cook region. Please try again.',
      );
      return false;
    }

    final cookRegion = _normalizeRegion(matchingCooks.first.address);
    if (cookRegion.isEmpty) {
      _showRegionError(
        'This cook has not selected a service region yet.',
      );
      return false;
    }

    if (cookRegion != customerRegion) {
      _showRegionError(
        'You can only order from cooks in your region.',
      );
      return false;
    }

    return true;
  }

  void _applyPromoCode() {
    final code = _promoController.text.trim().toUpperCase();
    final discount = switch (code) {
      'SAVE10' => 10.0,
      'FIRSTORDER' => 15.0,
      _ => 0.0,
    };
    setState(() => _discount = discount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          discount > 0 ? '$code applied' : 'Promo code is not valid',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: discount > 0 ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showPaymentSheet(CartProvider cart) async {
    if (!await _validateRegionForOrder(cart)) {
      return;
    }
    if (!mounted) return;

    var selectedId = _paymentId;
    final total = _total(cart);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, bottom: 18),
                        child: Text(
                          'Payment Method',
                          style: GoogleFonts.poppins(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _PaymentTile(
                        id: 'credit',
                        selectedId: selectedId,
                        title: 'Credit Card',
                        subtitle: '•••• 4242',
                        icon: Icons.credit_card_rounded,
                        onTap: () => setSheetState(() => selectedId = 'credit'),
                      ),
                      const SizedBox(height: 12),
                      _PaymentTile(
                        id: 'debit',
                        selectedId: selectedId,
                        title: 'Debit Card',
                        subtitle: '•••• 8888',
                        icon: Icons.payment_rounded,
                        onTap: () => setSheetState(() => selectedId = 'debit'),
                      ),
                      const SizedBox(height: 12),
                      _AddCardButton(onTap: _showAddCardMessage),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            _paymentId = selectedId;
                            Navigator.of(sheetContext).pop();
                            _confirmPayment(cart);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.homeChrome,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor:
                                AppColors.homeChrome.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            'Confirm & Pay ${total.toStringAsFixed(0)} SAR',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCardMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Add card flow will be connected next.',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmPayment(CartProvider cart) async {
    if (!await _validateRegionForOrder(cart)) {
      return;
    }
    if (!mounted) return;

    final customerRegion =
        _normalizeRegion(context.read<AuthProvider>().currentUser?.address);
    final cookId = cart.currentCookId ?? cart.items.first.dish.cookId;
    final cook = context
        .read<CookProvider>()
        .cooks
        .where((candidate) => candidate.id == cookId)
        .firstOrNull;
    final cookRegion = _normalizeRegion(cook?.address);

    if (cook == null) {
      _showRegionError('Unable to verify the cook. Please try again.');
      return;
    }

    if (!(cook.isOnline ?? false)) {
      _showRegionError(
          'The cook is currently offline. Please try again later.');
      return;
    }

    String paymentMethodId;
    String paymentCardMask;
    switch (_paymentId) {
      case 'debit':
        paymentMethodId = 'debit_card';
        paymentCardMask = '**** 8888';
        break;
      case 'cash':
        paymentMethodId = 'cash';
        paymentCardMask = 'CASH';
        break;
      case 'credit':
      default:
        paymentMethodId = 'credit_card';
        paymentCardMask = '**** 4242';
        break;
    }

    final ordersProvider = context.read<OrdersProvider>();

    try {
      final order = await ordersProvider.placeOrderFromCart(
        cartItems: cart.items,
        subtotal: cart.subtotal,
        totalAmount: _total(cart),
        paymentMethodId: paymentMethodId,
        paymentCardMask: paymentCardMask,
        cookRegion: cookRegion,
        deliveryAddress: customerRegion,
      );

      cart.clearCart();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment confirmed. Your order has been sent.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('${AppRoutes.orderWaitingApproval}/${order.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.cart);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBackTap});

  final String title;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: topPadding + 120,
      padding: EdgeInsets.fromLTRB(34, topPadding + 26, 28, 0),
      color: AppColors.homeChrome,
      child: Row(
        children: [
          Tooltip(
            message: 'Back to basket',
            child: Semantics(
              button: true,
              label: 'Back to basket',
              child: GestureDetector(
                onTap: onBackTap,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 42),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 25,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.onChangeTap});

  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final address = user?.address ?? '';

    return _Section(
      title: 'Delivery Address',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionIcon(
                icon: Icons.location_on_outlined,
                color: AppColors.success,
                background: Color(0xFFEFFAF0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Home', style: _smallStrong),
                    const SizedBox(height: 8),
                    Text(
                      address.isEmpty ? 'Address not set' : address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Region not selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoSection extends StatelessWidget {
  const _PromoSection({
    required this.controller,
    required this.discount,
    required this.onApplyTap,
    required this.onCodeTap,
  });

  final TextEditingController controller;
  final double discount;
  final VoidCallback onApplyTap;
  final ValueChanged<String> onCodeTap;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Promo Code',
      child: Column(
        children: [
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.local_offer_outlined,
                color: Color(0xFFFF7F4D),
                background: Color(0xFFFFF1EA),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Have a promo code? Enter it here to get a discount',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'ENTER PROMO CODE',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8D93A1),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F3),
                      border: _promoBorder(BorderSide.none),
                      enabledBorder: _promoBorder(BorderSide.none),
                      focusedBorder: _promoBorder(
                        const BorderSide(color: AppColors.homeChrome),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 68,
                height: 48,
                child: OutlinedButton(
                  onPressed: onApplyTap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE6E8EE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    'Apply',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discount > 0
                      ? 'Discount applied: ${discount.toStringAsFixed(0)} SAR'
                      : 'Try these codes:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _PromoChip(
                        label: 'SAVE10', onTap: () => onCodeTap('SAVE10')),
                    _PromoChip(
                      label: 'FIRSTORDER',
                      onTap: () => onCodeTap('FIRSTORDER'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _promoBorder(BorderSide side) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: side,
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.subtotal,
    required this.discount,
  });

  final double subtotal;
  final double discount;

  @override
  Widget build(BuildContext context) {
    final total = (subtotal - discount).clamp(0, double.infinity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _SummaryLine(label: 'Subtotal', value: subtotal),
            const SizedBox(height: 8),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _SummaryLine(
                label: 'Discount',
                value: -discount,
                valueColor: AppColors.success,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFE5E7EB)),
            ),
            _SummaryLine(
              label: 'Total',
              value: total.toDouble(),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final double value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(0)} SAR',
          style: GoogleFonts.cairo(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFECEEF2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _PromoChip extends StatelessWidget {
  const _PromoChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Use promo code $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE7E9EF)),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({required this.total, required this.onTap});

  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECEEF2))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.homeChrome,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Continue to Payment  ${total.toStringAsFixed(0)} SAR',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final TextStyle _smallStrong = GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: AppColors.textSecondary,
);

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.id,
    required this.selectedId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String selectedId;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = id == selectedId;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title payment method',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1FBF3) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? const Color(0xFF22B453) : const Color(0xFFE3E6EC),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE3F8E8)
                      : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFF16A34A)
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFCDD2DB),
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add new payment card',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD8DDE6)),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Add New Card',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
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

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your basket is empty',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
