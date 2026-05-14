import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:naham_app/screens/cook/cook_dish_form_screen.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/models/dish_model.dart';

class CookMenuScreen extends StatefulWidget {
  const CookMenuScreen({super.key});

  @override
  State<CookMenuScreen> createState() => _CookMenuScreenState();
}

class _CookMenuScreenState extends State<CookMenuScreen> {
  static const String _allCategoryId = 'all';
  String _selectedCategoryId = _allCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<DishProvider>().loadCookDishes(auth.currentUser!.id);
      }
    });
  }

  List<_CookMenuDish> get _menuDishes {
    final dishes = context.watch<DishProvider>().cookDishes;
    return dishes.map((d) => _fromDishModel(d)).toList();
  }

  _CookMenuDish _fromDishModel(DishModel model) {
    return _CookMenuDish(
      id: model.id,
      name: model.name,
      description: model.description,
      categoryId: model.categoryId,
      preparationTimeMin: model.preparationTimeMin,
      price: model.price,
      photos: model.imageUrl.isNotEmpty ? [model.imageUrl] : [],
      demand: _inferDemandFromModel(model),
      createdAt: model.createdAt,
    );
  }

  _AIDemand _inferDemandFromModel(DishModel model) {
    final prepMin = model.preparationTimeMin;
    final dishPrice = model.price;

    if (prepMin <= 25 && dishPrice <= 60) {
      return _AIDemand.high;
    }
    if (dishPrice >= 85 || prepMin >= 60) {
      return _AIDemand.low;
    }
    return _AIDemand.medium;
  }

  List<_CookMenuDish> get _visibleDishes {
    if (_selectedCategoryId == _allCategoryId) {
      return _menuDishes;
    }
    return _menuDishes
        .where((dish) => dish.categoryId == _selectedCategoryId)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 12),
              decoration: const BoxDecoration(
                color: AppColors.homeChrome,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Menu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 100,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(right: 8, left: 2),
                scrollDirection: Axis.horizontal,
                itemCount: _menuCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final category = _menuCategories[index];
                  final isSelected = category.id == _selectedCategoryId;
                  return _CategoryChip(
                    category: category,
                    isSelected: isSelected,
                    onTap: () {
                      if (isSelected) return;
                      setState(() => _selectedCategoryId = category.id);
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: context.watch<DishProvider>().isLoadingCookDishes
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleDishes.isEmpty
                      ? _MenuEmptyState(onAddTap: _openAddDish)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                          itemCount: _visibleDishes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final dish = _visibleDishes[index];
                            return _MenuDishCard(
                              dish: dish,
                              categoryLabel: _categoryLabel(dish.categoryId),
                              onEditTap: () => _openEditDish(dish),
                              onInsightTap: () => _showAiInsight(dish),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 72),
          child: FloatingActionButton(
            onPressed: _openAddDish,
            backgroundColor: const Color(0xFFA685EA),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 4,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }

  String _categoryLabel(String categoryId) {
    return _menuCategories
        .firstWhere(
          (item) => item.id == categoryId,
          orElse: () => const _MenuCategory(
            id: 'other',
            label: '\u0623\u062e\u0631\u0649',
            assetPath: 'assets/images/al_najdia.png',
          ),
        )
        .label;
  }

  void _handleBottomNavTap(int index) {
    if (index == 4) return;
    if (index == 0) {
      context.go(AppRoutes.cookReels);
      return;
    }
    if (index == 1) {
      context.go(AppRoutes.cookOrders);
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
    if (index == 3) {
      context.go(AppRoutes.cookChat);
    }
  }

  Future<void> _openAddDish() async {
    final result = await context.push<Object?>(
      AppRoutes.addEditDish,
      extra: const CookDishFormPayload.add(),
    );
    _applyDishFormResult(result, forEditingDishId: null);
  }

  Future<void> _openEditDish(_CookMenuDish dish) async {
    final result = await context.push<Object?>(
      AppRoutes.addEditDish,
      extra: CookDishFormPayload.edit(dishData: dish.toMap()),
    );
    _applyDishFormResult(result, forEditingDishId: dish.id);
  }

  void _applyDishFormResult(Object? result, {String? forEditingDishId}) {
    if (result is! Map) return;
    final action = result['action'];
    if (action != 'save') return;

    // The data is now saved through backend APIs by the form, and DishProvider
    // reloads the dishes automatically. We just show a snackbar.
    if (forEditingDishId == null) {
      _showSnack('Dish added successfully');
    } else {
      _showSnack('Dish updated successfully');
    }
  }

  void _showAiInsight(_CookMenuDish dish) {
    final (title, message, color) = switch (dish.demand) {
      _AIDemand.high => (
          'High demand',
          'Customers are actively searching for this dish right now. Keep it available to maximize orders.',
          const Color(0xFF1F9A6A),
        ),
      _AIDemand.medium => (
          'Stable demand',
          'This dish performs consistently. Promote it with a combo offer to increase sales.',
          const Color(0xFF7D67C4),
        ),
      _AIDemand.low => (
          'Low demand',
          'Demand is currently lower than average. Consider improving photos or adjusting price.',
          const Color(0xFFE07644),
        ),
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.insights_rounded, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Insight - ${dish.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _MenuCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  bool get _isRegionCategory {
    return const {
      'northern',
      'eastern',
      'southern',
      'najdi',
      'western',
    }.contains(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? AppColors.homeDeliveryGreen : const Color(0xFFC9D0CC);
    final labelColor =
        isSelected ? AppColors.homeDeliveryGreen : AppColors.homeSoftGreenDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: _isRegionCategory ? 70 : 76,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _isRegionCategory ? 62 : 60,
              height: _isRegionCategory ? 62 : 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6F3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 1.8 : 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1E000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(_isRegionCategory ? 8 : 11),
                child: Image.asset(category.assetPath, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: labelColor,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDishCard extends StatelessWidget {
  const _MenuDishCard({
    required this.dish,
    required this.categoryLabel,
    required this.onEditTap,
    required this.onInsightTap,
  });

  final _CookMenuDish dish;
  final String categoryLabel;
  final VoidCallback onEditTap;
  final VoidCallback onInsightTap;

  @override
  Widget build(BuildContext context) {
    final (insightTitle, insightSubtitle, insightColor, insightSurface) =
        switch (dish.demand) {
      _AIDemand.high => (
          'AI Insight',
          'High demand - Tap to view',
          const Color(0xFF1A9A69),
          const Color(0xFFE3F5ED),
        ),
      _AIDemand.medium => (
          'AI Insight',
          'Stable demand - Tap to view',
          const Color(0xFF7D67C4),
          const Color(0xFFEEE8FF),
        ),
      _AIDemand.low => (
          'AI Insight',
          'Low demand - Tap to view',
          const Color(0xFFE07644),
          const Color(0xFFFFEEE6),
        ),
    };

    final primaryImage = dish.photos.isNotEmpty ? dish.photos.first : '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E4EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: primaryImage.isEmpty
                    ? Container(
                        height: 172,
                        color: const Color(0xFFE8EBF1),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF96A0AF),
                          size: 30,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: primaryImage,
                        height: 172,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 172,
                          color: const Color(0xFFE8EBF1),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 172,
                          color: const Color(0xFFE8EBF1),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF96A0AF),
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: InkWell(
                  onTap: onEditTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Color(0xFF2D3138),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${dish.price.toStringAsFixed(2)} SAR',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF444E5D),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF233043),
                          height: 1.0,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        categoryLabel,
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7B8391),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onInsightTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: insightSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.86),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: insightColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insightTitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: insightColor,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                insightSubtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: insightColor.withValues(alpha: 0.86),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuEmptyState extends StatelessWidget {
  const _MenuEmptyState({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: Color(0xFFE8DFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Color(0xFF7A56B8),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No dishes in this category',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first dish and make it available for customers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAddTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8F6ED0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add new dish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCategory {
  const _MenuCategory({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;
}

class _CookMenuDish {
  const _CookMenuDish({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.preparationTimeMin,
    required this.price,
    required this.photos,
    required this.demand,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String categoryId;
  final int preparationTimeMin;
  final double price;
  final List<String> photos;
  final _AIDemand demand;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'preparationTimeMin': preparationTimeMin,
      'price': price,
      'photos': photos,
    };
  }

  _CookMenuDish copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    int? preparationTimeMin,
    double? price,
    List<String>? photos,
    _AIDemand? demand,
    DateTime? createdAt,
  }) {
    return _CookMenuDish(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      preparationTimeMin: preparationTimeMin ?? this.preparationTimeMin,
      price: price ?? this.price,
      photos: photos ?? this.photos,
      demand: demand ?? this.demand,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum _AIDemand {
  high,
  medium,
  low,
}

const List<_MenuCategory> _menuCategories = [
  _MenuCategory(
    id: 'all',
    label: '\u0627\u0644\u0643\u0644',
    assetPath: 'assets/images/all_saudi_arabia.png',
  ),
  _MenuCategory(
    id: 'northern',
    label: '\u0634\u0645\u0627\u0644\u064a\u0629',
    assetPath: 'assets/images/al_shamalia.png',
  ),
  _MenuCategory(
    id: 'eastern',
    label: '\u0634\u0631\u0642\u064a\u0629',
    assetPath: 'assets/images/al_sharqia.png',
  ),
  _MenuCategory(
    id: 'southern',
    label: '\u062c\u0646\u0648\u0628\u064a\u0629',
    assetPath: 'assets/images/al_janobia.png',
  ),
  _MenuCategory(
    id: 'najdi',
    label: '\u0646\u062c\u062f\u064a\u0629',
    assetPath: 'assets/images/al_najdia.png',
  ),
  _MenuCategory(
    id: 'western',
    label: '\u063a\u0631\u0628\u064a\u0629',
    assetPath: 'assets/images/al_garbia.png',
  ),
  _MenuCategory(
    id: 'sweets',
    label: '\u062d\u0644\u0648\u064a\u0627\u062a',
    assetPath: 'assets/images/cookie.png',
  ),
  _MenuCategory(
    id: 'baked',
    label: '\u0645\u0639\u062c\u0646\u0627\u062a',
    assetPath: 'assets/images/baked.png',
  ),
];

