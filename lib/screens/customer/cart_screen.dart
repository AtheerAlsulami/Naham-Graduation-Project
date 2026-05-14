import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/cart_item_model.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
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
            _BasketHeader(onBackTap: () => _goBack(context)),
            Expanded(
              child: cart.items.isEmpty
                  ? const _EmptyBasket()
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        _BasketItemsSection(cart: cart),
                        _OrderNotesSection(controller: _notesController),
                      ],
                    ),
            ),
            if (cart.items.isNotEmpty) _BasketCheckoutBar(cart: cart),
          ],
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.customerHome);
  }
}

class _BasketHeader extends StatelessWidget {
  const _BasketHeader({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: topPadding + 80,
      padding: EdgeInsets.fromLTRB(10, topPadding + 8, 18, 0),
      color: AppColors.homeChrome,
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            tooltip: 'Back to home',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          Expanded(
            child: Text(
              'Your Basket',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BasketItemsSection extends StatelessWidget {
  const _BasketItemsSection({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFECEEF2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text(
              'Items',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          ...cart.items.map((item) {
            return _BasketItemTile(
              item: item,
              onRemove: () => cart.removeItem(item.dish.id),
              onDecrease: () => cart.updateQuantity(
                item.dish.id,
                item.quantity - 1,
              ),
              onIncrease: () => cart.updateQuantity(
                item.dish.id,
                item.quantity + 1,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BasketItemTile extends StatelessWidget {
  const _BasketItemTile({
    required this.item,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
  });

  final CartItemModel item;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFECEEF2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.0,
                        ),
                        children: [
                          const TextSpan(text: 'each  '),
                          TextSpan(
                            text: '${item.dish.price.toStringAsFixed(0)} SAR',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove ${item.dish.name}',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 32, height: 28),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuantityCircleButton(
                icon: Icons.remove_rounded,
                label: 'Decrease ${item.dish.name} quantity',
                onTap: onDecrease,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _QuantityCircleButton(
                icon: Icons.add_rounded,
                label: 'Increase ${item.dish.name} quantity',
                onTap: onIncrease,
              ),
              const Spacer(),
              Text(
                '${item.totalPrice.toStringAsFixed(0)} SAR',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityCircleButton extends StatelessWidget {
  const _QuantityCircleButton({
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
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success, width: 1.4),
            ),
            child: Icon(
              icon,
              size: 15,
              color: AppColors.success,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderNotesSection extends StatelessWidget {
  const _OrderNotesSection({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Notes',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 5,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Add any special instructions for the cook...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: const Color(0xFFEFEFF2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: AppColors.homeChrome),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasketCheckoutBar extends StatelessWidget {
  const _BasketCheckoutBar({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECEEF2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Subtotal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cart.subtotal.toStringAsFixed(0)} SAR',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.checkout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.homeChrome,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Proceed to Checkout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBasket extends StatelessWidget {
  const _EmptyBasket();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.homeMintSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your basket is empty',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add meals from cooks, then complete your checkout here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
