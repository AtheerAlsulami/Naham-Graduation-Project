import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/models/food_category_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/core/providers/notifications_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/screens/customer/customer_chat_screen.dart';
import 'package:naham_app/screens/customer/customer_orders_screen.dart';
import 'package:naham_app/screens/customer/customer_profile_screen.dart';
import 'package:naham_app/screens/customer/customer_reels_screen.dart';
import 'package:naham_app/screens/customer/widgets/customer_shell_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/providers/dish_provider.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.initialTab,
    this.initialConversationId,
    this.initialOrderImage,
  });

  final String? initialTab;
  final String? initialConversationId;
  final String? initialOrderImage;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const int _tabReels = 0;
  static const int _tabOrders = 1;
  static const int _tabHome = 2;
  static const int _tabChat = 3;
  static const int _tabProfile = 4;

  int _currentIndex = 2;
  final Set<int> _loadedTabIndexes = {2};
  bool _isEditingProfile = false;
  String? _selectedChatConversationId;
  bool _supportChatOpenedFromProfile = false;

  static const _titles = [
    'Reels',
    'My Orders',
    'Naham',
    'chat',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _applyIncomingRouteState(shouldSetState: false);
  }

  @override
  void didUpdateWidget(covariant CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialConversationId != widget.initialConversationId) {
      _applyIncomingRouteState(shouldSetState: true);
    }
  }

  void _applyIncomingRouteState({required bool shouldSetState}) {
    final requestedTab = widget.initialTab?.trim().toLowerCase();
    if (requestedTab != 'chat') {
      return;
    }

    final conversationId = widget.initialConversationId?.trim();
    void apply() {
      _loadedTabIndexes.add(_tabChat);
      _currentIndex = _tabChat;
      _isEditingProfile = false;
      _supportChatOpenedFromProfile = false;
      _selectedChatConversationId =
          (conversationId != null && conversationId.isNotEmpty)
              ? conversationId
              : null;
    }

    if (shouldSetState) {
      setState(apply);
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().items.length;
    final unreadNotifications =
        context.watch<NotificationsProvider>().unreadCount;

    return CustomerShellScaffold(
      title: _titles[_currentIndex],
      currentIndex: _currentIndex,
      cartCount: cartCount,
      notificationCount: unreadNotifications,
      topBar: _buildTopBar(),
      showBottomNav: !(_currentIndex == 3 &&
          _selectedChatConversationId == ChatProvider.supportConversationId),
      onTabSelected: (index) {
        setState(() {
          _loadedTabIndexes.add(index);
          _currentIndex = index;
          if (index != _tabProfile) {
            _isEditingProfile = false;
          }
          if (index != _tabChat) {
            _selectedChatConversationId = null;
            _supportChatOpenedFromProfile = false;
          }
        });
      },
      onSearchTap: () => context.push(AppRoutes.search),
      onCartTap: () => context.push(AppRoutes.cart),
      onNotificationsTap: () => context.push(AppRoutes.customerNotifications),
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _titles.length,
          _buildTabContent,
          growable: false,
        ),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    if (!_loadedTabIndexes.contains(index)) {
      return const SizedBox.shrink();
    }

    switch (index) {
      case _tabReels:
        return CustomerReelsScreen(isActive: _currentIndex == _tabReels);
      case _tabOrders:
        return const CustomerOrdersScreen();
      case _tabHome:
        return const _HomeTabContent();
      case _tabChat:
        return CustomerChatScreen(
          selectedConversationId: _selectedChatConversationId,
          referenceImageUrl: widget.initialOrderImage,
          onConversationSelected: (conversationId) {
            context.read<ChatProvider>().markRead(conversationId);
            setState(() {
              _selectedChatConversationId = conversationId;
              _supportChatOpenedFromProfile = false;
            });
          },
          onBackToList: () {
            setState(() {
              if (_selectedChatConversationId ==
                      ChatProvider.supportConversationId &&
                  _supportChatOpenedFromProfile) {
                _currentIndex = _tabProfile;
                _supportChatOpenedFromProfile = false;
              }
              _selectedChatConversationId = null;
            });
          },
        );
      case _tabProfile:
        return CustomerProfileScreen(
          isEditing: _isEditingProfile,
          onEditRequested: () {
            setState(() {
              _isEditingProfile = true;
            });
          },
          onEditClosed: () {
            setState(() {
              _isEditingProfile = false;
            });
          },
          onSupportChatRequested: () async {
            final chatProvider = context.read<ChatProvider>();
            await chatProvider.ensureSupportConversation();
            await chatProvider.markRead(ChatProvider.supportConversationId);
            if (!mounted) {
              return;
            }
            setState(() {
              _loadedTabIndexes.add(_tabChat);
              _currentIndex = _tabChat;
              _isEditingProfile = false;
              _selectedChatConversationId = ChatProvider.supportConversationId;
              _supportChatOpenedFromProfile = true;
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildTopBar() {
    if (_currentIndex == 0) {
      return const SizedBox.shrink();
    }

    if (_currentIndex == 3) {
      return const SizedBox.shrink();
    }

    if (_currentIndex == 4) {
      return CustomerProfileTopBar(
        isEditing: _isEditingProfile,
        onBackTap: () {
          setState(() {
            _isEditingProfile = false;
          });
        },
      );
    }

    return null;
  }
}

class _HomeTabContent extends StatefulWidget {
  const _HomeTabContent();

  @override
  State<_HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<_HomeTabContent> {
  static const List<FoodCategoryModel> _categories = NahamFoodCategories.all;
  static const int _initialDishesLimit = 30;
  static const Duration _initialLoadDelay = Duration(milliseconds: 220);
  static const Duration _staggerDelay = Duration(milliseconds: 120);

  late String _selectedCategoryId = _categories.first.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_primeHomeData());
    });
  }

  Future<void> _primeHomeData() async {
    await Future<void>.delayed(_initialLoadDelay);
    if (!mounted) return;

    unawaited(
      context.read<DishProvider>().loadCustomerDishes(
            limit: _initialDishesLimit,
          ),
    );

    await Future<void>.delayed(_staggerDelay);
    if (!mounted) return;
    unawaited(context.read<CookProvider>().loadCooks());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final dishProvider = context.watch<DishProvider>();
    final cookProvider = context.watch<CookProvider>();
    final customerRegion = _normalizeRegion(user?.address);
    final regionCookIds = cookProvider.cooks
        .where((cook) => _normalizeRegion(cook.address) == customerRegion)
        .map((cook) => cook.id)
        .toSet();
    final activeDishes = customerRegion.isEmpty
        ? <DishModel>[]
        : dishProvider.customerDishes
            .where((dish) => regionCookIds.contains(dish.cookId))
            .take(10)
            .toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        Row(
          children: [
            Text(
              'Categories',
              style: _sectionTitleStyle,
            ),
            const Spacer(),
            _DeliveryChip(
              label: _resolveDeliveryLabel(user?.address),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (customerRegion.isEmpty) ...[
          const _RegionRequiredNotice(
            message:
                'Select your region in your profile to see nearby cooks and place orders successfully.',
          ),
          const SizedBox(height: 14),
        ],
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 8, left: 2),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _CategoryFilterChip(
                category: category,
                isSelected: _selectedCategoryId == category.id,
                onTap: () {
                  setState(() => _selectedCategoryId = category.id);
                  context.push('${AppRoutes.categoryDishes}/${category.id}');
                },
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'active Dishes',
          onTap: () => context.push(AppRoutes.search),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200, // Increased height to prevent overflow
          child: dishProvider.isLoadingCustomerDishes ||
                  (customerRegion.isNotEmpty && cookProvider.isLoading)
              ? const Center(child: CircularProgressIndicator())
              : dishProvider.error != null
                  ? Center(
                      child: Text(
                        'Error: ${dishProvider.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : activeDishes.isEmpty
                      ? Center(
                          child: Text(
                            customerRegion.isEmpty
                                ? 'Set your region to see available dishes'
                                : 'No dishes available in your region right now',
                            style: GoogleFonts.poppins(
                                color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: activeDishes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return _DishPreviewCard(dish: activeDishes[index]);
                          },
                        ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Top cooks this month',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final cooks = customerRegion.isEmpty
                ? <UserModel>[]
                : cookProvider.cooks
                    .where((cook) =>
                        _normalizeRegion(cook.address) == customerRegion)
                    .toList(growable: false);

            if (customerRegion.isNotEmpty && cookProvider.isLoading) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (cooks.isEmpty) {
              if (cookProvider.error != null) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  child: Text(
                    'Error: ${cookProvider.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                child: Text(
                  customerRegion.isEmpty
                      ? 'Set your region to see available cooks'
                      : 'No cooks available in your region right now',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cook = cooks[index];
                return _CookPreviewCard(
                  cook: cook,
                  onTap: () async {
                    context.push(
                      AppRoutes.cookProfile,
                      extra: {
                        'id': cook.id,
                        'name': cook.displayName ?? cook.name,
                        'specialty': cook.specialty,
                        'rating': cook.rating,
                        'imageUrl': cook.profileImageUrl,
                        'currentMonthOrders': cook.currentMonthOrders,
                        'totalOrders': cook.totalOrders ?? 0,
                        'address': cook.address,
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _resolveDeliveryLabel(String? address) {
    final region = _normalizeRegion(address);
    if (region.isEmpty) {
      return 'Select your region';
    }

    return 'Available in  $region';
  }

  String _normalizeRegion(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return AppConstants.saudiRegions.contains(trimmed) ? trimmed : '';
  }
}

class _RegionRequiredNotice extends StatelessWidget {
  const _RegionRequiredNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.homeDeliveryGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 14,
            color: Color(0xFFF4FBEF),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF4FBEF),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: Color(0xFFF4FBEF),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: _sectionTitleStyle,
        ),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'See all',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final FoodCategoryModel category;
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

class _DishPreviewCard extends StatelessWidget {
  const _DishPreviewCard({required this.dish});

  final DishModel dish;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.dishDetail}/${dish.id}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.homeCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: CachedNetworkImage(
                imageUrl: dish.imageUrl,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  color: AppColors.homeDivider,
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: AppColors.homeDivider,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F3EA),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dish.rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${dish.price.toStringAsFixed(0)} SAR',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookPreviewCard extends StatelessWidget {
  const _CookPreviewCard({required this.cook, required this.onTap});

  final UserModel cook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.homeCardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildCookAvatar(cook),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cook.displayName ?? cook.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${cook.rating?.toStringAsFixed(1) ?? '0.0'} • 0.5 mi away',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cook.currentMonthOrders} orders',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'this month',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookAvatar(UserModel cook) {
    final imagePath = cook.profileImageUrl?.trim();
    final fallbackAsset = _defaultAvatarAssetFor(cook);

    if (imagePath != null && imagePath.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 56,
          height: 56,
          color: AppColors.homeDivider,
        ),
        errorWidget: (context, url, error) => Image.asset(
          fallbackAsset,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      fallbackAsset,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
    );
  }

  String _defaultAvatarAssetFor(UserModel user) {
    final name = '${user.displayName ?? ''} ${user.name}'.toLowerCase();
    const femaleTokens = [
      'maria',
      'sara',
      'amal',
      'fat',
      'reem',
      'nour',
      'hana',
      'layla',
      'mona',
    ];

    for (final token in femaleTokens) {
      if (name.contains(token)) {
        return 'assets/images/default_female_profile_image.png';
      }
    }

    return 'assets/images/default_male_profile_image.png';
  }
}

final TextStyle _sectionTitleStyle = GoogleFonts.poppins(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
  height: 1.0,
);
