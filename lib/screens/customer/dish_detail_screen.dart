import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class DishDetailScreen extends StatefulWidget {
  final String dishId;
  const DishDetailScreen({super.key, required this.dishId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dishProvider = context.read<DishProvider>();
      if (dishProvider.customerDishes.isEmpty &&
          !dishProvider.isLoadingCustomerDishes) {
        dishProvider.loadCustomerDishes(limit: 250);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dishProvider = context.watch<DishProvider>();
    final dish = dishProvider.findDishById(widget.dishId);

    if (dish == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Dish not found',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Image Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: dish.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppColors.shimmerBase,
                  highlightColor: AppColors.shimmerHighlight,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textHint, size: 50),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish.name,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => context.push(
                                  AppRoutes.cookProfile,
                                  extra: _buildCookProfileData(dish),
                                ),
                                child: Text(
                                  'From: ${dish.cookName}',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${dish.price} SAR',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    if (!dish.isAvailable) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'This dish is currently unavailable',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Rating & Preparation Time
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${dish.rating} (${dish.reviewsCount} Reviews)',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.textHint, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${dish.preparationTimeMin}-${dish.preparationTimeMax} minutes',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Description
                    const Text(
                      'Dish Description',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dish.description,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Ingredients
                    if (dish.ingredients.isNotEmpty) ...[
                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: dish.ingredients
                            .map((ingredient) =>
                                _buildIngredientChip(ingredient))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 100), // padding for bottom bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Add to Cart Bar
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity Control
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (quantity > 1) setState(() => quantity--);
                      },
                      icon: const Icon(Icons.remove_rounded,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      quantity.toString(),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => quantity++),
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Add to Cart Button
              Expanded(
                child: ElevatedButton(
                  onPressed: !dish.isAvailable
                      ? null
                      : () {
                          try {
                            context
                                .read<CartProvider>()
                                .addItem(dish, quantity);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${dish.name} added to cart',
                                    style:
                                        const TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            context
                                .pop(); // Optional: return to previous screen
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                    style:
                                        const TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_cart_outlined,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Add - ${(dish.price * quantity).toStringAsFixed(1)} SAR',
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Map<String, dynamic> _buildCookProfileData(DishModel dish) {
    final cookProvider = context.read<CookProvider>();
    final matchedCook =
        cookProvider.cooks.where((c) => c.id == dish.cookId).firstOrNull;

    final imageFromCook = matchedCook?.profileImageUrl?.trim();
    final ratingFromCook = matchedCook?.rating;

    return {
      'id': dish.cookId.trim().isEmpty ? dish.id : dish.cookId.trim(),
      'name': dish.cookName.trim().isEmpty ? 'Cook' : dish.cookName.trim(),
      'specialty': dish.description,
      'rating': ratingFromCook ?? dish.rating,
      'distance': 'Nearby',
      'imageUrl': (imageFromCook != null && imageFromCook.isNotEmpty)
          ? imageFromCook
          : dish.imageUrl,
    };
  }
}
