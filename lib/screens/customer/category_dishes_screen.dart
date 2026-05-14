import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/models/food_category_model.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:provider/provider.dart';

class CategoryDishesScreen extends StatefulWidget {
  const CategoryDishesScreen({
    super.key,
    required this.categoryId,
  });

  final String categoryId;

  @override
  State<CategoryDishesScreen> createState() => _CategoryDishesScreenState();
}

class _CategoryDishesScreenState extends State<CategoryDishesScreen> {
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
    final category = NahamFoodCategories.byId(widget.categoryId);
    final dishProvider = context.watch<DishProvider>();
    final dishes = dishProvider.customerDishes
        .where((dish) => dish.categoryId == category.id)
        .toList(growable: false);
    final isLoading = dishProvider.isLoadingCustomerDishes;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _CategoryHeader(category: category),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dishes.isEmpty
                      ? _EmptyCategoryState(category: category)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(30, 12, 28, 32),
                          itemCount: dishes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 18),
                          itemBuilder: (context, index) {
                            return _CategoryDishCard(dish: dishes[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final FoodCategoryModel category;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: topPadding + 112,
      padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 14),
      decoration: const BoxDecoration(
        color: AppColors.homeSoftGreen,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const SizedBox(
              width: 34,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 34,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 26),
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.homeIconCircle,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.74),
                width: 2,
              ),
            ),
            child: Image.asset(
              category.assetPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 26),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                category.title,
                maxLines: 1,
                style: GoogleFonts.cairo(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDishCard extends StatelessWidget {
  const _CategoryDishCard({required this.dish});

  final DishModel dish;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('${AppRoutes.dishDetail}/${dish.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7EEE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: dish.imageUrl,
                      height: 206,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 206,
                        color: AppColors.homeDivider,
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 206,
                        color: AppColors.homeDivider,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 12,
                    child: _RatingPill(rating: dish.rating),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                                dish.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dish.cookName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Text(
                          '${dish.price.toStringAsFixed(0)} SAR',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _addToBasket(context, dish),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B6B24),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 22),
                        label: const Text('Add to Basket'),
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

  void _addToBasket(BuildContext context, DishModel dish) {
    try {
      context.read<CartProvider>().addItem(dish, 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${dish.name} added to basket',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({required this.category});

  final FoodCategoryModel category;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              category.assetPath,
              width: 86,
              height: 86,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              'No dishes available yet',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New dishes will be added to this category soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
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
