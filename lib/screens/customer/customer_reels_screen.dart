import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/models/reel_comment_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/follow_provider.dart';
import 'package:naham_app/services/reel_service.dart';
import 'package:naham_app/widgets/reel_video_surface.dart';
import 'package:provider/provider.dart';

class CustomerReelsScreen extends StatefulWidget {
  const CustomerReelsScreen({
    super.key,
    this.isActive = true,
  });

  final bool isActive;

  @override
  State<CustomerReelsScreen> createState() => _CustomerReelsScreenState();
}

class _CustomerReelsScreenState extends State<CustomerReelsScreen> {
  final PageController _pageController = PageController();
  final ReelService _reelService = ReelService.instance;
  StreamSubscription<List<CookReelModel>>? _reelsSubscription;

  _ReelsFeed _selectedFeed = _ReelsFeed.forYou;
  bool _isLoading = true;
  List<CookReelModel> _savedReels = const [];
  List<_ReelItem> _reels = [];

  @override
  void initState() {
    super.initState();
    _subscribeToReels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<CookProvider>().loadCooks(force: true).then((_) {
          if (!mounted || _savedReels.isEmpty) return;
          setState(() {
            _reels = _savedReels.map(_mapDbReelToReelItem).toList();
          });
        }),
      );
    });
  }

  void _subscribeToReels() {
    _reelsSubscription?.cancel();
    _reelsSubscription = _reelService.watchReels().listen(
      (savedReels) {
        if (!mounted) {
          return;
        }
        setState(() {
          _savedReels = savedReels;
          _reels = savedReels.map(_mapDbReelToReelItem).toList();
          _isLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() => _isLoading = false);
      },
    );
  }

  _ReelItem _mapDbReelToReelItem(CookReelModel reel) {
    final creatorName = reel.creatorName.isEmpty ? '@cook' : reel.creatorName;
    final cookId = _resolveCookId(reel, creatorName);
    final latestCook = _findCookByIdOrName(cookId, creatorName);
    final latestCreatorName = latestCook?.displayName?.trim().isNotEmpty == true
        ? latestCook!.displayName!.trim()
        : latestCook?.name.trim();
    final resolvedCreatorName =
        latestCreatorName != null && latestCreatorName.isNotEmpty
            ? latestCreatorName
            : creatorName;
    final latestCreatorImage = latestCook?.profileImageUrl?.trim();
    final resolvedCreatorImage =
        latestCreatorImage != null && latestCreatorImage.isNotEmpty
            ? latestCreatorImage
            : reel.creatorImageUrl;
    final creatorLabel =
        reel.title.trim().isEmpty ? reel.description : reel.title;
    return _ReelItem(
      id: reel.id,
      creatorId: cookId,
      title: reel.title,
      description: reel.description,
      imageUrl: reel.imageUrl,
      videoPath: reel.videoPath,
      creatorImageUrl: resolvedCreatorImage,
      creatorName: resolvedCreatorName,
      creatorLabel: creatorLabel,
      audioLabel: reel.audioLabel,
      likes: reel.likes,
      commentsCount: reel.comments,
      shares: reel.shares,
      isCookSpotlight: true,
      cookData: {
        'id': cookId,
        'name': resolvedCreatorName,
        'specialty': latestCook?.specialty ?? reel.description,
        'rating': latestCook?.rating ?? 4.7,
        'distance': 'Nearby',
        'imageUrl': resolvedCreatorImage ?? '',
        'profileImageUrl': resolvedCreatorImage ?? '',
        'currentMonthOrders': latestCook?.currentMonthOrders ?? 0,
        'totalOrders': latestCook?.totalOrders ?? 0,
      },
      comments: reel.commentItems,
      isLiked: reel.isLiked,
      isBookmarked: reel.isBookmarked,
      isFollowing: reel.isFollowing,
      isPaused: reel.isPaused,
      createdAt: reel.createdAt,
    );
  }

  String _resolveCookId(CookReelModel reel, String creatorName) {
    final creatorId = reel.creatorId.trim();
    if (creatorId.isNotEmpty) {
      return creatorId;
    }

    final normalizedName = creatorName.trim().toLowerCase();

    final dishes = context.read<DishProvider>().customerDishes;
    for (final dish in dishes) {
      if (dish.cookId.trim().isEmpty) {
        continue;
      }
      if (dish.cookName.trim().toLowerCase() == normalizedName) {
        return dish.cookId.trim();
      }
    }

    final cooks = context.read<CookProvider>().cooks;
    for (final cook in cooks) {
      if (cook.name.trim().toLowerCase() == normalizedName ||
          (cook.displayName ?? '').trim().toLowerCase() == normalizedName) {
        return cook.id;
      }
    }

    return reel.id;
  }

  UserModel? _findCookByIdOrName(String cookId, String creatorName) {
    final normalizedName = creatorName.trim().toLowerCase();
    for (final cook in context.read<CookProvider>().cooks) {
      if (cookId.isNotEmpty && cook.id == cookId) {
        return cook;
      }
      final displayName = (cook.displayName ?? '').trim().toLowerCase();
      if (normalizedName.isNotEmpty &&
          (cook.name.trim().toLowerCase() == normalizedName ||
              displayName == normalizedName)) {
        return cook;
      }
    }
    return null;
  }

  List<_ReelItem> get _visibleReels {
    if (_selectedFeed == _ReelsFeed.forYou) {
      return _reels;
    }

    return _reels.where((reel) => reel.isCookSpotlight).toList();
  }

  @override
  void dispose() {
    _reelsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final reels = _visibleReels;

    if (reels.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          itemBuilder: (context, index) {
            final reel = reels[index];
            final creatorId =
                reel.creatorId.trim().isEmpty ? reel.id : reel.creatorId;
            final followProvider = context.watch<FollowProvider>();
            final isFollowing = followProvider.isFollowing(creatorId);

            return _ReelPage(
              reel: reel.copyWith(isFollowing: isFollowing),
              isActive: widget.isActive,
              onTogglePlay: () => _togglePaused(reel.id),
              onToggleLike: () => _toggleLike(reel.id),
              onToggleBookmark: () => _toggleBookmark(reel.id),
              onToggleFollow: () {
                followProvider.toggleFollow(
                  cookId: creatorId,
                  shouldFollow: !isFollowing,
                );
              },
              onCommentsTap: () => _showCommentsSheet(reel.id),
              onShareTap: () => _shareReel(reel.id),
              onCreatorTap: () =>
                  context.push(AppRoutes.cookProfile, extra: reel.cookData),
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              _ReelsHeader(
                onSearchTap: () => context.push(AppRoutes.search),
                onMoreTap: _showMoreSheet,
              ),
              const SizedBox(height: 12),
              _FeedToggle(
                selectedFeed: _selectedFeed,
                onFeedChanged: (feed) {
                  setState(() {
                    _selectedFeed = feed;
                  });
                  _pageController.jumpToPage(0);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
                Icons.play_circle_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No cook reels yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch back to reels  to browse every reel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePaused(String reelId) {
    _updateReel(
      reelId,
      (reel) => reel.copyWith(isPaused: !reel.isPaused),
    );
  }

  void _toggleLike(String reelId) {
    var likeDelta = 0;
    final updated = _updateReelAndReturn(reelId, (reel) {
      final nextLiked = !reel.isLiked;
      likeDelta = nextLiked ? 1 : -1;
      return reel.copyWith(
        isLiked: nextLiked,
        likes:
            nextLiked ? reel.likes + 1 : (reel.likes > 0 ? reel.likes - 1 : 0),
      );
    });
    if (updated == null) {
      return;
    }
    unawaited(
      _persistReelState(
        updated,
        actionLabel: 'like update',
        likeDelta: likeDelta,
      ),
    );
  }

  void _toggleBookmark(String reelId) {
    final updated = _updateReelAndReturn(
      reelId,
      (reel) => reel.copyWith(isBookmarked: !reel.isBookmarked),
    );
    if (updated == null) {
      return;
    }
    unawaited(
      _persistReelState(
        updated,
        actionLabel: 'save update',
      ),
    );
  }

  Future<void> _shareReel(String reelId) async {
    final reel = _findReel(reelId);
    if (reel == null) return;

    await Clipboard.setData(
      ClipboardData(text: 'https://naham.app/reels/${reel.id}'),
    );

    if (!mounted) return;

    _updateReel(
      reelId,
      (item) => item.copyWith(shares: item.shares + 1),
    );
    _showSnack('Reel link copied to clipboard');
  }

  Future<void> _showCommentsSheet(String reelId) async {
    final controller = TextEditingController();

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
            final reel = _findReel(reelId);
            final comments = reel?.comments ?? const <ReelCommentModel>[];

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
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
                  const SizedBox(height: 16),
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.homeMintSurface,
                              child: Text(
                                comment.userName.isNotEmpty
                                    ? comment.userName[0]
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.userName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.text,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: 'Add a comment',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5),
                            filled: true,
                            fillColor: AppColors.homeMintSurface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;

                            final currentUser =
                                context.read<AuthProvider>().currentUser;
                            final userName = currentUser?.name ?? 'User';
                            final userId = currentUser?.id ?? 'unknown';

                            final newComment = ReelCommentModel(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              userId: userId,
                              userName: userName,
                              userImageUrl: currentUser?.profileImageUrl,
                              text: text,
                              createdAt: DateTime.now(),
                            );

                            _updateReel(
                              reelId,
                              (reel) {
                                final updated = reel.copyWith(
                                  commentsCount: reel.commentsCount + 1,
                                  comments: [
                                    ...reel.comments,
                                    newComment,
                                  ],
                                );
                                // Persist the change
                                unawaited(_persistReelState(updated,
                                    actionLabel: 'comment'));
                                return updated;
                              },
                            );
                            controller.clear();
                            setModalState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.homeChrome,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Send',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreSheet() {
    final reels = _visibleReels;
    if (reels.isEmpty) return;

    final reel = reels[
        _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
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
              const SizedBox(height: 16),
              _MoreActionTile(
                icon: Icons.visibility_off_outlined,
                label: 'Not interested',
                onTap: () {
                  Navigator.of(context).pop();
                  _showSnack('We will show fewer reels like this');
                },
              ),
              _MoreActionTile(
                icon: Icons.flag_outlined,
                label: 'Report reel',
                onTap: () {
                  Navigator.of(context).pop();
                  _showSnack('Report submitted');
                },
              ),
              _MoreActionTile(
                icon: Icons.storefront_outlined,
                label: 'Open cook profile',
                onTap: () {
                  Navigator.of(context).pop();
                  this
                      .context
                      .push(AppRoutes.cookProfile, extra: reel.cookData);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  _ReelItem? _findReel(String reelId) {
    for (final reel in _reels) {
      if (reel.id == reelId) return reel;
    }

    return null;
  }

  void _updateReel(String reelId, _ReelItem Function(_ReelItem reel) update) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index < 0) return;

    setState(() {
      _reels[index] = update(_reels[index]);
    });
  }

  _ReelItem? _updateReelAndReturn(
    String reelId,
    _ReelItem Function(_ReelItem reel) update,
  ) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index < 0) {
      return null;
    }

    late _ReelItem updatedReel;
    setState(() {
      updatedReel = update(_reels[index]);
      _reels[index] = updatedReel;
    });
    return updatedReel;
  }

  Future<void> _persistReelState(
    _ReelItem reel, {
    required String actionLabel,
    int likeDelta = 0,
  }) async {
    try {
      await _reelService.saveReel(
        reel.toCookReelModel(),
        likedByUserId: context.read<AuthProvider>().currentUser?.id,
        likeDelta: likeDelta,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to sync $actionLabel');
    }
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

class _ReelsHeader extends StatelessWidget {
  const _ReelsHeader({
    required this.onSearchTap,
    required this.onMoreTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      color: AppColors.homeChrome,
      child: Row(
        children: [
          const Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Reels',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          _HeaderIconButton(
            icon: Icons.search_rounded,
            onTap: onSearchTap,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.more_vert_rounded,
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 21,
        color: Colors.white,
      ),
    );
  }
}

class _FeedToggle extends StatelessWidget {
  const _FeedToggle({
    required this.selectedFeed,
    required this.onFeedChanged,
  });

  final _ReelsFeed selectedFeed;
  final ValueChanged<_ReelsFeed> onFeedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeedChip(
            label: 'reels ',
            isActive: selectedFeed == _ReelsFeed.forYou,
            onTap: () => onFeedChanged(_ReelsFeed.forYou),
          ),
          const SizedBox(width: 6),
          _FeedChip(
            label: 'Cooks',
            isActive: selectedFeed == _ReelsFeed.cooks,
            onTap: () => onFeedChanged(_ReelsFeed.cooks),
          ),
        ],
      ),
    );
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.authButtonEnd : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.reel,
    required this.isActive,
    required this.onTogglePlay,
    required this.onToggleLike,
    required this.onToggleBookmark,
    required this.onToggleFollow,
    required this.onCommentsTap,
    required this.onShareTap,
    required this.onCreatorTap,
  });

  final _ReelItem reel;
  final bool isActive;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleFollow;
  final VoidCallback onCommentsTap;
  final VoidCallback onShareTap;
  final VoidCallback onCreatorTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTogglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ReelCover(
            reel: reel,
            isActive: isActive,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          if (reel.isPaused)
            Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 128,
            child: Column(
              children: [
                _ReelActionButton(
                  icon: reel.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: _compactCount(reel.likes),
                  iconColor: Colors.white,
                  activeColor: const Color(0xFFFF6A7D),
                  isActive: reel.isLiked,
                  onTap: onToggleLike,
                ),
                const SizedBox(height: 16),
                _ReelActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: '${reel.commentsCount}',
                  iconColor: Colors.white,
                  activeColor: Colors.white,
                  isActive: false,
                  onTap: onCommentsTap,
                ),
                const SizedBox(height: 16),
                _ReelActionButton(
                  icon: Icons.reply_rounded,
                  label: 'Share',
                  iconColor: Colors.white,
                  activeColor: Colors.white,
                  isActive: false,
                  onTap: onShareTap,
                ),
                const SizedBox(height: 16),
                _ReelActionButton(
                  icon: reel.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: '',
                  iconColor: Colors.white,
                  activeColor: Colors.white,
                  isActive: reel.isBookmarked,
                  onTap: onToggleBookmark,
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 76,
            bottom: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onCreatorTap,
                      child: _CreatorAvatar(
                        imageUrl: reel.creatorImageUrl,
                        name: reel.creatorName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: onCreatorTap,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          reel.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onToggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: reel.isFollowing
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          reel.isFollowing ? 'Following' : 'Follow',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: reel.isFollowing
                                ? Colors.white
                                : AppColors.authButtonEnd,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onCreatorTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    reel.creatorLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reel.audioLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
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
}

class _ReelCover extends StatelessWidget {
  const _ReelCover({
    required this.reel,
    required this.isActive,
  });

  final _ReelItem reel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final imageUrl = reel.imageUrl;
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFF1E1C20),
        ),
        errorWidget: (context, url, error) => _buildVideoOrFallbackCover(),
      );
    }

    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        File(imageUrl).existsSync()) {
      return Image.file(File(imageUrl), fit: BoxFit.cover);
    }

    return _buildVideoOrFallbackCover();
  }

  Widget _buildVideoOrFallbackCover() {
    final path = reel.videoPath;
    if (path != null && path.isNotEmpty) {
      return ReelVideoSurface(
        source: path,
        isPaused: reel.isPaused || !isActive,
      );
    }

    return Container(
      color: const Color(0xFF1E1C20),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 42,
        color: Colors.white70,
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final path = imageUrl?.trim();
    final fallbackAsset = _defaultAvatarAssetFor(name);

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: (path != null && path.isNotEmpty && path.startsWith('http'))
            ? CachedNetworkImage(
                imageUrl: path,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Image.asset(
                  fallbackAsset,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                fallbackAsset,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  String _defaultAvatarAssetFor(String name) {
    final lowerName = name.toLowerCase();
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
      if (lowerName.contains(token)) {
        return 'assets/images/default_female_profile_image.png';
      }
    }

    return 'assets/images/default_male_profile_image.png';
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color activeColor;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = isActive ? activeColor : iconColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 26, color: resolvedColor),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

enum _ReelsFeed {
  forYou,
  cooks,
}

class _ReelItem {
  const _ReelItem({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.videoPath,
    this.creatorImageUrl,
    required this.creatorName,
    required this.creatorLabel,
    required this.audioLabel,
    required this.likes,
    required this.commentsCount,
    required this.shares,
    required this.isCookSpotlight,
    required this.cookData,
    required this.comments,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isFollowing = false,
    this.isPaused = true,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoPath;
  final String? creatorImageUrl;
  final String creatorName;
  final String creatorLabel;
  final String audioLabel;
  final int likes;
  final int commentsCount;
  final int shares;
  final bool isCookSpotlight;
  final Map<String, dynamic> cookData;
  final List<ReelCommentModel> comments;
  final bool isLiked;
  final bool isBookmarked;
  final bool isFollowing;
  final bool isPaused;
  final DateTime createdAt;

  _ReelItem copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? description,
    String? imageUrl,
    String? videoPath,
    String? creatorImageUrl,
    String? creatorName,
    String? creatorLabel,
    String? audioLabel,
    int? likes,
    int? commentsCount,
    int? shares,
    bool? isCookSpotlight,
    Map<String, dynamic>? cookData,
    List<ReelCommentModel>? comments,
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
    bool? isPaused,
    DateTime? createdAt,
  }) {
    return _ReelItem(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      videoPath: videoPath ?? this.videoPath,
      creatorImageUrl: creatorImageUrl ?? this.creatorImageUrl,
      creatorName: creatorName ?? this.creatorName,
      creatorLabel: creatorLabel ?? this.creatorLabel,
      audioLabel: audioLabel ?? this.audioLabel,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      shares: shares ?? this.shares,
      isCookSpotlight: isCookSpotlight ?? this.isCookSpotlight,
      cookData: cookData ?? this.cookData,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFollowing: isFollowing ?? this.isFollowing,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  CookReelModel toCookReelModel() {
    return CookReelModel(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorImageUrl: creatorImageUrl,
      title: title,
      description: description,
      imageUrl: imageUrl,
      videoPath: videoPath ?? '',
      audioLabel: audioLabel,
      likes: likes,
      comments: commentsCount,
      shares: shares,
      isMine: false,
      isFollowing: isFollowing,
      isLiked: isLiked,
      isPaused: isPaused,
      isBookmarked: isBookmarked,
      isDraft: false,
      commentItems: comments,
      createdAt: createdAt,
    );
  }
}

// Remove _ReelComment class as it is replaced by ReelCommentModel

String _compactCount(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}k';
  }

  return '$value';
}
