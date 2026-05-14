import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/follow_provider.dart';
import 'package:provider/provider.dart';

class CookProfileScreen extends StatefulWidget {
  const CookProfileScreen({super.key, required this.cookData});

  final Map<String, dynamic> cookData;

  @override
  State<CookProfileScreen> createState() => _CookProfileScreenState();
}

class _CookProfileScreenState extends State<CookProfileScreen> {
  late final Map<String, dynamic> _cook;
  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    _cook = _normalizedCookData(widget.cookData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cookId = _cook['id'] as String;
      context.read<CookProvider>().loadCooks(force: true);
      if (cookId.isNotEmpty) {
        context.read<DishProvider>().loadCookDishes(cookId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cookId = _cook['id'] as String;
    final dishProvider = context.watch<DishProvider>();
    final cookProvider = context.watch<CookProvider>();
    UserModel? latestCook;
    for (final cook in cookProvider.cooks) {
      if (cook.id == cookId) {
        latestCook = cook;
        break;
      }
    }

    final latestImageUrl = latestCook?.profileImageUrl?.trim();
    final headerImageUrl = latestImageUrl != null && latestImageUrl.isNotEmpty
        ? latestImageUrl
        : _cook['imageUrl'] as String;
    final displayName =
        (latestCook?.displayName ?? latestCook?.name)?.toString().trim();
    final specialty = latestCook?.specialty?.trim();
    final profileName = displayName != null && displayName.isNotEmpty
        ? displayName
        : _cook['name'] as String;
    final profileSpecialty = specialty != null && specialty.isNotEmpty
        ? specialty
        : _cook['specialty'] as String;
    final isOnline = latestCook?.isOnline ?? (_cook['isOnline'] == true);
    final cookDishes = dishProvider.cookDishes
        .where((dish) => dish.cookId == cookId)
        .toList()
      ..sort((a, b) {
        final monthly = b.currentMonthOrders.compareTo(a.currentMonthOrders);
        if (monthly != 0) return monthly;
        return b.totalOrders.compareTo(a.totalOrders);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: cookId.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: 'cook-profile-chat-$cookId',
              onPressed:
                  _isOpeningChat ? null : () => _openCookChat(latestCook),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: _isOpeningChat
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_rounded),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeaderImage(headerImageUrl),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  if (profileName.isNotEmpty || profileSpecialty.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profileName.isNotEmpty)
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profileName,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFF2EA05B)
                                        : const Color(0xFF888888),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? Colors.white
                                              : const Color(0xFFCCCCCC),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                _FollowButton(cookId: cookId),
                              ],
                            ),
                          if (profileName.isNotEmpty &&
                              profileSpecialty.isNotEmpty)
                            const SizedBox(height: 4),
                          if (profileSpecialty.isNotEmpty)
                            Text(
                              profileSpecialty,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    Icons.star_rounded,
                    _formatOptionalValue(_cook['rating']),
                    'Rating',
                  ),
                  _divider(),
                  _buildStatItem(
                    Icons.local_fire_department_rounded,
                    '${_cook['currentMonthOrders']}',
                    'Orders This Month',
                  ),
                  _divider(),
                  _buildStatItem(
                    Icons.receipt_long_rounded,
                    '${_cook['totalOrders']}',
                    'Total Orders',
                  ),
                  _divider(),
                  _buildStatItem(
                    Icons.restaurant_menu_rounded,
                    cookDishes.length.toString(),
                    'Dishes',
                  ),
                  _divider(),
                  _buildStatItem(
                    Icons.people_alt_rounded,
                    '${latestCook?.followersCount ?? _cook['followersCount']}',
                    'Followers',
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Most Ordered Dishes This Month',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (dishProvider.isLoadingCookDishes)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (cookDishes.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Text(
                  'No dishes available for this cook at the moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemBuilder: (context, index) {
                  return _CookProfileDishCard(dish: cookDishes[index]);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: cookDishes.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: AppColors.border);
  }

  Widget _buildHeaderImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(color: AppColors.surfaceVariant);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: AppColors.homeDivider),
      errorWidget: (context, url, error) =>
          Container(color: AppColors.surfaceVariant),
    );
  }

  Future<void> _openCookChat(UserModel? latestCook) async {
    final cookId = _cook['id'] as String;
    if (cookId.trim().isEmpty) {
      _showSnack('Unable to open a chat with this cook.');
      return;
    }

    final fallbackName = (_cook['name'] as String).trim();
    final cookName = latestCook?.displayName?.trim().isNotEmpty == true
        ? latestCook!.displayName!.trim()
        : (latestCook?.name.trim().isNotEmpty == true
            ? latestCook!.name.trim()
            : fallbackName);

    if (cookName.isEmpty) {
      _showSnack('Cook information is not available yet.');
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      final conversationId =
          await context.read<ChatProvider>().createConversation(
                otherUserId: cookId,
                otherUserName: cookName,
                type: ChatParticipantType.cook,
              );

      if (!mounted) return;
      final encodedConversation = Uri.encodeComponent(conversationId);
      context.go(
          '${AppRoutes.customerHome}?tab=chat&conversation=$encodedConversation');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOpeningChat = false);
      _showSnack('Failed to open the chat with this cook.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildStatItem(IconData icon, String val, String title) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _normalizedCookData(Map<String, dynamic> source) {
    final id = _readText(source['id']);
    final name = _readText(source['name']);
    final specialty = _readText(source['specialty']);
    final profileImageUrl = _readText(source['profileImageUrl']);
    final imageUrl = profileImageUrl.isNotEmpty
        ? profileImageUrl
        : _readText(source['imageUrl']);

    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'rating': _readOptionalRating(source['rating']),
      'currentMonthOrders': _readInt(source['currentMonthOrders']),
      'totalOrders': _readInt(source['totalOrders']),
      'followersCount': _readInt(source['followersCount']),
      'imageUrl': imageUrl,
      'isOnline': source['isOnline'] == true,
    };
  }

  String _readText(Object? value) {
    return value?.toString().trim() ?? '';
  }

  Object? _readOptionalRating(Object? value) {
    if (value is num) return value;
    if (value is String && value.trim().isNotEmpty) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  String _formatOptionalValue(Object? value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

class _CookProfileDishCard extends StatelessWidget {
  const _CookProfileDishCard({required this.dish});

  final DishModel dish;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.dishDetail}/${dish.id}'),
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 116,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
                child: CachedNetworkImage(
                  imageUrl: dish.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OrderBadge(
                          icon: Icons.local_fire_department_rounded,
                          label: '${dish.currentMonthOrders} this month',
                        ),
                        const SizedBox(width: 6),
                        _OrderBadge(
                          icon: Icons.receipt_long_rounded,
                          label: '${dish.totalOrders} total',
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${dish.price.toStringAsFixed(0)} SAR',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 16,
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

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.cookId});

  final String cookId;

  @override
  Widget build(BuildContext context) {
    if (cookId.isEmpty) return const SizedBox.shrink();

    final followProvider = context.watch<FollowProvider>();
    final isFollowing = followProvider.isFollowing(cookId);

    return GestureDetector(
      onTap: () {
        followProvider.toggleFollow(
          cookId: cookId,
          shouldFollow: !isFollowing,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(999),
          border: isFollowing ? Border.all(color: Colors.white) : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
