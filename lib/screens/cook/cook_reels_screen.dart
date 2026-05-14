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
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:naham_app/models/reel_comment_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/follow_provider.dart';
import 'package:naham_app/services/reel_service.dart';
import 'package:naham_app/widgets/reel_video_surface.dart';
import 'package:provider/provider.dart';

enum _CookReelsFeed { forYou, cooks, myReels }

class CookReelsScreen extends StatefulWidget {
  const CookReelsScreen({super.key});

  @override
  State<CookReelsScreen> createState() => _CookReelsScreenState();
}

class _CookReelsScreenState extends State<CookReelsScreen> {
  final PageController _pageController = PageController();
  _CookReelsFeed _selectedFeed = _CookReelsFeed.forYou;
  final ReelService _reelService = ReelService.instance;
  StreamSubscription<List<CookReelModel>>? _reelsSubscription;

  bool _isLoadingReels = true;
  List<CookReelModel> _savedReels = const [];
  List<_CookReelItem> _reels = [];
  List<_MyCookReel> _myReels = [];
  String _currentUserId = '';
  String _currentCreatorName = '@cook';

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthProvider>().currentUser;
    _currentUserId = currentUser?.id ?? '';
    _currentCreatorName = _resolveCreatorName(currentUser);
    _subscribeToReels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<CookProvider>().loadCooks(force: true).then((_) {
          if (!mounted || _savedReels.isEmpty) return;
          _remapSavedReels();
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
        _savedReels = savedReels;

        final mappedReels = savedReels.map((reel) {
          final creatorName =
              reel.creatorName.isEmpty ? _currentCreatorName : reel.creatorName;
          final latestCook = _findCookByIdOrName(reel.creatorId, creatorName);
          final latestImage = _latestCreatorImage(reel, latestCook);
          final latestName = latestCook?.displayName?.trim().isNotEmpty == true
              ? latestCook!.displayName!.trim()
              : latestCook?.name.trim();
          final resolvedCreatorName =
              latestName != null && latestName.isNotEmpty
                  ? latestName
                  : creatorName;
          final isMine = reel.creatorId == _currentUserId ||
              (_currentUserId.isNotEmpty &&
                  reel.creatorId.isEmpty &&
                  creatorName == _currentCreatorName);
          return _CookReelItem(
            id: reel.id,
            creatorId: reel.creatorId,
            creatorName: resolvedCreatorName,
            creatorImageUrl: latestImage,
            imageUrl: reel.imageUrl,
            description: reel.description,
            audioLabel: reel.audioLabel,
            likes: reel.likes,
            comments: reel.comments,
            commentItems: reel.commentItems,
            shares: reel.shares,
            isMine: isMine,
            isFollowing: reel.isFollowing,
            videoPath: reel.videoPath,
            createdAt: reel.createdAt,
          );
        }).toList();

        final mappedMyReels = savedReels.where((reel) {
          final creatorName =
              reel.creatorName.isEmpty ? _currentCreatorName : reel.creatorName;
          return reel.creatorId == _currentUserId ||
              (_currentUserId.isNotEmpty &&
                  reel.creatorId.isEmpty &&
                  creatorName == _currentCreatorName);
        }).map((reel) {
          final creatorName =
              reel.creatorName.isEmpty ? _currentCreatorName : reel.creatorName;
          return _MyCookReel(
            id: reel.id,
            creatorName: creatorName,
            title: reel.title,
            audioLabel: reel.audioLabel,
            ageLabel: _formatAgeLabel(reel.createdAt),
            views: reel.likes,
            comments: reel.comments,
            imageUrl: reel.imageUrl,
            videoPath: reel.videoPath,
            isDraft: reel.isDraft,
          );
        }).toList();

        setState(() {
          _reels = mappedReels;
          _myReels = mappedMyReels;
          _isLoadingReels = false;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() => _isLoadingReels = false);
      },
    );
  }

  void _remapSavedReels() {
    final mappedReels = _savedReels.map((reel) {
      final creatorName =
          reel.creatorName.isEmpty ? _currentCreatorName : reel.creatorName;
      final latestCook = _findCookByIdOrName(reel.creatorId, creatorName);
      final latestName = latestCook?.displayName?.trim().isNotEmpty == true
          ? latestCook!.displayName!.trim()
          : latestCook?.name.trim();
      final resolvedCreatorName = latestName != null && latestName.isNotEmpty
          ? latestName
          : creatorName;
      final isMine = reel.creatorId == _currentUserId ||
          (_currentUserId.isNotEmpty &&
              reel.creatorId.isEmpty &&
              creatorName == _currentCreatorName);
      return _CookReelItem(
        id: reel.id,
        creatorId: reel.creatorId,
        creatorName: resolvedCreatorName,
        creatorImageUrl: _latestCreatorImage(reel, latestCook),
        imageUrl: reel.imageUrl,
        description: reel.description,
        audioLabel: reel.audioLabel,
        likes: reel.likes,
        comments: reel.comments,
        commentItems: reel.commentItems,
        shares: reel.shares,
        isMine: isMine,
        isFollowing: reel.isFollowing,
        videoPath: reel.videoPath,
        createdAt: reel.createdAt,
      );
    }).toList();

    setState(() {
      _reels = mappedReels;
      _isLoadingReels = false;
    });
  }

  UserModel? _findCookByIdOrName(String cookId, String creatorName) {
    if (cookId == _currentUserId ||
        creatorName.trim().toLowerCase() ==
            _currentCreatorName.trim().toLowerCase()) {
      return context.read<AuthProvider>().currentUser;
    }
    final normalizedName = creatorName.trim().toLowerCase();
    for (final cook in context.read<CookProvider>().cooks) {
      if (cookId.isNotEmpty && cook.id == cookId) return cook;
      final displayName = (cook.displayName ?? '').trim().toLowerCase();
      if (normalizedName.isNotEmpty &&
          (cook.name.trim().toLowerCase() == normalizedName ||
              displayName == normalizedName)) {
        return cook;
      }
    }
    return null;
  }

  String? _latestCreatorImage(CookReelModel reel, UserModel? latestCook) {
    final latestImage = latestCook?.profileImageUrl?.trim();
    if (latestImage != null && latestImage.isNotEmpty) {
      return latestImage;
    }
    return reel.creatorImageUrl;
  }

  List<_CookReelItem> get _visibleReels {
    return switch (_selectedFeed) {
      _CookReelsFeed.forYou => _reels,
      _CookReelsFeed.cooks => _reels.where((reel) => !reel.isMine).toList(),
      _CookReelsFeed.myReels => const <_CookReelItem>[],
    };
  }

  String _formatAgeLabel(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    }
    return 'Just now';
  }

  String _resolveCreatorName(dynamic user) {
    final displayName = user?.displayName?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      return '@$displayName';
    }
    final name = user?.name?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return '@$name';
    }
    final email = user?.email?.toString();
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) {
        return '@$prefix';
      }
    }
    return '@cook';
  }

  @override
  void dispose() {
    _reelsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMyReels = _selectedFeed == _CookReelsFeed.myReels;
    final reels = _visibleReels;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isMyReels ? Colors.white : Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_isLoadingReels)
              const Center(child: CircularProgressIndicator())
            else if (isMyReels)
              _MyCookReelsPanel(
                reels: _myReels,
                onAddTap: _openReelCamera,
                onPlayTap: _previewMyReel,
                onMoreTap: _showMyReelActions,
              )
            else if (reels.isEmpty)
              _EmptyCookReels(feed: _selectedFeed)
            else
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

                  return _CookReelPage(
                    reel: reel.copyWith(isFollowing: isFollowing),
                    onPlayTap: () => _togglePaused(reel.id),
                    onLikeTap: () => _toggleLike(reel.id),
                    onCommentTap: () => _showCommentsSheet(reel),
                    onShareTap: () => _shareReel(reel),
                    onBookmarkTap: () => _toggleBookmark(reel.id),
                    onFollowTap: () {
                      if (reel.isMine) return;
                      followProvider.toggleFollow(
                        cookId: creatorId,
                        shouldFollow: !isFollowing,
                      );
                    },
                    onMoreTap: () => _showReelActions(reel),
                  );
                },
              ),
            _CookReelsHeader(onCreateTap: _openReelCamera),
            _CookFeedTabs(
              selectedFeed: _selectedFeed,
              isLight: isMyReels,
              onChanged: (feed) {
                setState(() => _selectedFeed = feed);
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 0,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == 0) return;
    _pauseAllReels();
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
    if (index == 4) {
      context.go(AppRoutes.myMenu);
      return;
    }
    if (index == 3) {
      context.go(AppRoutes.cookChat);
    }
  }

  void _pauseAllReels() {
    setState(() {
      _reels = _reels
          .map((r) => r.isPaused ? r : r.copyWith(isPaused: true))
          .toList();
    });
  }

  void _togglePaused(String reelId) {
    _updateReel(reelId, (reel) => reel.copyWith(isPaused: !reel.isPaused));
  }

  void _toggleLike(String reelId) {
    var likeDelta = 0;
    final updated = _updateReelAndReturn(reelId, (reel) {
      final liked = !reel.isLiked;
      likeDelta = liked ? 1 : -1;
      return reel.copyWith(
        isLiked: liked,
        likes: liked ? reel.likes + 1 : (reel.likes > 0 ? reel.likes - 1 : 0),
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
    unawaited(_persistReelState(updated, actionLabel: 'save update'));
  }

  void _updateReel(
      String reelId, _CookReelItem Function(_CookReelItem) update) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index == -1) return;
    setState(() => _reels[index] = update(_reels[index]));
  }

  _CookReelItem? _updateReelAndReturn(
    String reelId,
    _CookReelItem Function(_CookReelItem) update,
  ) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index == -1) {
      return null;
    }
    late _CookReelItem updated;
    setState(() {
      updated = update(_reels[index]);
      _reels[index] = updated;
    });
    return updated;
  }

  Future<void> _persistReelState(
    _CookReelItem reel, {
    required String actionLabel,
    int likeDelta = 0,
  }) async {
    try {
      await _reelService.saveReel(
        reel.toCookReelModel(),
        likedByUserId: context.read<AuthProvider>().currentUser?.id,
        likeDelta: likeDelta,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to sync $actionLabel');
    }
  }

  void _showCommentsSheet(_CookReelItem reel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _CookCommentsSheet(
          reel: reel,
          onClose: () => Navigator.of(context).pop(),
          onCommentAdded: (newComment) {
            _updateReel(
              reel.id,
              (item) {
                final updated = item.copyWith(
                  comments: item.comments + 1,
                  commentItems: [...item.commentItems, newComment],
                );
                unawaited(_persistReelState(updated, actionLabel: 'comment'));
                return updated;
              },
            );
          },
        );
      },
    );
  }

  void _shareReel(_CookReelItem reel) {
    Clipboard.setData(
        ClipboardData(text: 'https://naham.app/reels/${reel.id}'));
    final updated = _updateReelAndReturn(
      reel.id,
      (item) => item.copyWith(shares: item.shares + 1),
    );
    if (updated != null) {
      unawaited(_persistReelState(updated, actionLabel: 'share update'));
    }
    _showSnack('Reel link copied to clipboard');
  }

  void _showReelActions(_CookReelItem reel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ReelActionsSheet(
          reel: reel,
          onEdit: () {
            Navigator.of(context).pop();
            _showSnack('Reel editor will open next');
          },
          onBoost: () {
            Navigator.of(context).pop();
            _showSnack('Promotion options will open next');
          },
          onDelete: () async {
            Navigator.of(context).pop();
            if (!reel.isMine) {
              _showSnack('Only your reels can be deleted');
              return;
            }
            try {
              await _reelService.deleteReel(reel.id);
              _showSnack('Reel removed');
            } catch (error) {
              if (!mounted) return;
              _showSnack('Delete failed: $error');
            }
          },
        );
      },
    );
  }

  Future<void> _openReelCamera() async {
    await context.push<bool>(AppRoutes.cookReelCamera);
  }

  void _previewMyReel(_MyCookReel reel) {
    if (reel.isDraft) {
      _showSnack('Draft reel is not published yet');
      return;
    }
    final preview = _CookReelItem(
      id: reel.id,
      creatorId: _currentUserId,
      imageUrl: reel.imageUrl,
      videoPath: reel.videoPath,
      creatorName: reel.creatorName,
      description: reel.title,
      audioLabel: reel.audioLabel,
      likes: reel.views,
      comments: reel.comments,
      shares: 0,
      isMine: true,
      createdAt: DateTime.now(),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
          child: _CookReelPage(
            reel: preview,
            onPlayTap: () {},
            onLikeTap: () {},
            onCommentTap: () => _showCommentsSheet(preview),
            onShareTap: () => _shareReel(preview),
            onBookmarkTap: () {},
            onFollowTap: () {},
            onMoreTap: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _showMyReelActions(_MyCookReel reel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _MyReelActionsSheet(
          reel: reel,
          onEdit: () {
            Navigator.of(context).pop();
            _showSnack('Opening editor for ${reel.title}');
          },
          onPublish: () {
            Navigator.of(context).pop();
            if (!reel.isDraft) {
              _showSnack('${reel.title} is already published');
              return;
            }
            setState(() {
              final index = _myReels.indexWhere((item) => item.id == reel.id);
              if (index != -1) {
                _myReels[index] = reel.copyWith(isDraft: false);
              }
            });
            _showSnack('${reel.title} published');
          },
          onDelete: () async {
            Navigator.of(context).pop();
            try {
              await _reelService.deleteReel(reel.id);
              _showSnack('${reel.title} deleted');
            } catch (error) {
              if (!mounted) return;
              _showSnack('Delete failed: $error');
            }
          },
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

class _CookReelPage extends StatelessWidget {
  const _CookReelPage({
    required this.reel,
    required this.onPlayTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onBookmarkTap,
    required this.onFollowTap,
    required this.onMoreTap,
  });

  final _CookReelItem reel;
  final VoidCallback onPlayTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onFollowTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    Widget reelCover;
    if (reel.imageUrl != null && reel.imageUrl!.startsWith('http')) {
      reelCover = CachedNetworkImage(
        imageUrl: reel.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const ColoredBox(
          color: Color(0xFF1E1D20),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorWidget: (context, url, error) => const ColoredBox(
          color: Color(0xFF1E1D20),
          child: Icon(Icons.broken_image_rounded, color: Colors.white),
        ),
      );
    } else if (reel.imageUrl != null && File(reel.imageUrl!).existsSync()) {
      reelCover = Image.file(
        File(reel.imageUrl!),
        fit: BoxFit.cover,
      );
    } else if (reel.videoPath != null && reel.videoPath!.trim().isNotEmpty) {
      reelCover = ReelVideoSurface(
        source: reel.videoPath!.trim(),
        isPaused: reel.isPaused,
      );
    } else {
      reelCover = const ColoredBox(color: Color(0xFF1E1D20));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        reelCover,
        const _ReelGradientOverlay(),
        Center(
          child: Tooltip(
            message: reel.isPaused ? 'Play reel' : 'Pause reel',
            child: Semantics(
              button: true,
              label: reel.isPaused ? 'Play reel' : 'Pause reel',
              child: GestureDetector(
                onTap: onPlayTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.02),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    reel.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: reel.isPaused ? 82 : 58,
                    color: Colors.white.withValues(
                      alpha: reel.isPaused ? 1.0 : 0.86,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 124,
          child: _ReelActionsColumn(
            reel: reel,
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
            onBookmarkTap: onBookmarkTap,
          ),
        ),
        Positioned(
          left: 22,
          right: 20,
          bottom: 18,
          child: _CookReelInfo(
            reel: reel,
            onFollowTap: onFollowTap,
            onMoreTap: onMoreTap,
          ),
        ),
      ],
    );
  }
}

class _CookReelsHeader extends StatelessWidget {
  const _CookReelsHeader({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        height: topPadding + 78,
        padding: EdgeInsets.fromLTRB(28, topPadding + 17, 24, 0),
        color: AppColors.homeChrome,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: 'Create reel',
              child: Semantics(
                button: true,
                label: 'Create reel',
                child: IconButton(
                  onPressed: onCreateTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Reels',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 36, height: 36),
          ],
        ),
      ),
    );
  }
}

class _CookFeedTabs extends StatelessWidget {
  const _CookFeedTabs({
    required this.selectedFeed,
    required this.isLight,
    required this.onChanged,
  });

  final _CookReelsFeed selectedFeed;
  final bool isLight;
  final ValueChanged<_CookReelsFeed> onChanged;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      left: 66,
      right: 54,
      top: topPadding + 91,
      child: Container(
        height: 37,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFE9E9E9).withValues(alpha: 0.88)
              : Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _FeedTabButton(
              label: 'reels ',
              isSelected: selectedFeed == _CookReelsFeed.forYou,
              isLight: isLight,
              onTap: () => onChanged(_CookReelsFeed.forYou),
            ),
            _FeedTabButton(
              label: 'Cooks',
              isSelected: selectedFeed == _CookReelsFeed.cooks,
              isLight: isLight,
              onTap: () => onChanged(_CookReelsFeed.cooks),
            ),
            _FeedTabButton(
              label: 'My Reels',
              isSelected: selectedFeed == _CookReelsFeed.myReels,
              isLight: isLight,
              onTap: () => onChanged(_CookReelsFeed.myReels),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTabButton extends StatelessWidget {
  const _FeedTabButton({
    required this.label,
    required this.isSelected,
    required this.isLight,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.homeChrome
                      : isLight
                          ? const Color(0xFF7D7D83).withValues(alpha: 0.46)
                          : Colors.white.withValues(alpha: 0.66),
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelGradientOverlay extends StatelessWidget {
  const _ReelGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.04),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.62),
          ],
          stops: const [0.0, 0.4, 0.68, 1.0],
        ),
      ),
    );
  }
}

class _ReelActionsColumn extends StatelessWidget {
  const _ReelActionsColumn({
    required this.reel,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onBookmarkTap,
  });

  final _CookReelItem reel;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReelActionButton(
          icon: reel.isLiked ? Icons.favorite_rounded : Icons.favorite_rounded,
          label: _compactNumber(reel.likes),
          semanticLabel: reel.isLiked ? 'Unlike reel' : 'Like reel',
          color: reel.isLiked ? const Color(0xFFFF5B7D) : Colors.white,
          onTap: onLikeTap,
        ),
        const SizedBox(height: 20),
        _ReelActionButton(
          icon: Icons.chat_bubble_rounded,
          label: '${reel.comments}',
          semanticLabel: 'Open comments',
          onTap: onCommentTap,
          iconSize: 24,
        ),
        const SizedBox(height: 20),
        _ReelActionButton(
          icon: Icons.reply_rounded,
          label: 'Share',
          semanticLabel: 'Share reel',
          onTap: onShareTap,
          iconSize: 29,
          rotateQuarterTurns: 2,
        ),
        const SizedBox(height: 20),
        _ReelActionButton(
          icon: reel.isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: '',
          semanticLabel: reel.isBookmarked ? 'Remove saved reel' : 'Save reel',
          onTap: onBookmarkTap,
          iconSize: 25,
        ),
      ],
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.color = Colors.white,
    this.iconSize = 27,
    this.rotateQuarterTurns = 0,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color color;
  final double iconSize;
  final int rotateQuarterTurns;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: iconSize, color: color);

    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                RotatedBox(
                  quarterTurns: rotateQuarterTurns,
                  child: iconWidget,
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CookReelInfo extends StatelessWidget {
  const _CookReelInfo({
    required this.reel,
    required this.onFollowTap,
    required this.onMoreTap,
  });

  final _CookReelItem reel;
  final VoidCallback onFollowTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CreatorAvatar(
              imageUrl: reel.creatorImageUrl,
              name: reel.creatorName,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reel.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 5),
                  ],
                ),
              ),
            ),
            if (!reel.isMine)
              _FollowButton(
                isFollowing: reel.isFollowing,
                onTap: onFollowTap,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          reel.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.music_note_rounded, color: Colors.white, size: 17),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                reel.audioLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
            Tooltip(
              message: 'More reel actions',
              child: Semantics(
                button: true,
                label: 'More reel actions',
                child: GestureDetector(
                  onTap: onMoreTap,
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    // ignore: unused_element_parameter
    required this.onTap,
    // ignore: unused_element_parameter
    this.label,
  });

  final bool isFollowing;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (isFollowing ? 'Following' : 'Follow');

    return Tooltip(
      message: text,
      child: Semantics(
        button: true,
        label: text,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 27,
            constraints: const BoxConstraints(minWidth: 78),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              text,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyCookReelsPanel extends StatelessWidget {
  const _MyCookReelsPanel({
    required this.reels,
    required this.onAddTap,
    required this.onPlayTap,
    required this.onMoreTap,
  });

  final List<_MyCookReel> reels;
  final VoidCallback onAddTap;
  final ValueChanged<_MyCookReel> onPlayTap;
  final ValueChanged<_MyCookReel> onMoreTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18, topPadding + 144, 18, 112),
            itemCount: reels.length,
            separatorBuilder: (context, index) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final reel = reels[index];
              return _MyCookReelCard(
                reel: reel,
                onPlayTap: () => onPlayTap(reel),
                onMoreTap: () => onMoreTap(reel),
              );
            },
          ),
          Positioned(
            right: 18,
            bottom: bottomPadding + 18,
            child: Tooltip(
              message: 'Add new reel',
              child: Semantics(
                button: true,
                label: 'Add new reel',
                child: FloatingActionButton(
                  heroTag: 'cook-reels-add',
                  elevation: 6,
                  backgroundColor: AppColors.homeChrome,
                  foregroundColor: Colors.white,
                  onPressed: onAddTap,
                  child: const Icon(Icons.add_rounded, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyCookReelCard extends StatelessWidget {
  const _MyCookReelCard({
    required this.reel,
    required this.onPlayTap,
    required this.onMoreTap,
  });

  final _MyCookReel reel;
  final VoidCallback onPlayTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 102),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Tooltip(
            message: reel.isDraft ? 'Open draft' : 'Preview reel',
            child: Semantics(
              button: true,
              label: reel.isDraft ? 'Open draft' : 'Preview reel',
              child: GestureDetector(
                onTap: onPlayTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: reel.imageUrl != null &&
                              reel.imageUrl!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: reel.imageUrl!,
                              width: 82,
                              height: 74,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ColoredBox(
                                color: Color(0xFFEFEFEF),
                              ),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(
                                color: Color(0xFFEFEFEF),
                                child:
                                    Icon(Icons.broken_image_rounded, size: 22),
                              ),
                            )
                          : Container(
                              width: 82,
                              height: 74,
                              color: const Color(0xFFEFEFEF),
                              child: const Center(
                                child: Icon(Icons.videocam_rounded,
                                    color: AppColors.homeChrome, size: 28),
                              ),
                            ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.homeChrome,
                        size: 25,
                      ),
                    ),
                    if (reel.isDraft)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD13D),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Draft',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  reel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reel.ageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 12.5,
                      color: Color(0xFFB8B8BE),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _compactNumber(reel.views),
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: const Color(0xFF9B9BA4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 12.5,
                      color: Color(0xFFB8B8BE),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reel.comments}',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: const Color(0xFF9B9BA4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Reel options',
            child: Semantics(
              button: true,
              label: 'Reel options',
              child: IconButton(
                onPressed: onMoreTap,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF8D8D95),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCookReels extends StatelessWidget {
  const _EmptyCookReels({required this.feed});

  final _CookReelsFeed feed;

  @override
  Widget build(BuildContext context) {
    final title = switch (feed) {
      _CookReelsFeed.forYou => 'No reels yet',
      _CookReelsFeed.cooks => 'No cook reels yet',
      _CookReelsFeed.myReels => 'You have no reels yet',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1B22), Color(0xFF32283F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.movie_creation_outlined,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload short cooking clips to show your dishes and kitchen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookCommentsSheet extends StatefulWidget {
  const _CookCommentsSheet({
    required this.reel,
    required this.onClose,
    required this.onCommentAdded,
  });

  final _CookReelItem reel;
  final VoidCallback onClose;
  final Function(ReelCommentModel) onCommentAdded;

  @override
  State<_CookCommentsSheet> createState() => _CookCommentsSheetState();
}

class _CookCommentsSheetState extends State<_CookCommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.reel.commentItems;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Comments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close comments',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to reply!',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _CommentRow(
                    name: comment.userName,
                    text: comment.text,
                    time: _formatTime(comment.createdAt),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Write a reply...',
              suffixIcon: IconButton(
                tooltip: 'Send comment',
                onPressed: _sendComment,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUser = context.read<AuthProvider>().currentUser;
    final newComment = ReelCommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: currentUser?.id ?? 'unknown',
      userName: currentUser?.name ?? 'User',
      userImageUrl: currentUser?.profileImageUrl,
      text: text,
      createdAt: DateTime.now(),
    );

    widget.onCommentAdded(newComment);
    _controller.clear();
    setState(() {});
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.name,
    required this.text,
    required this.time,
  });

  final String name;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.homeChrome.withValues(alpha: 0.2),
            child: Text(
              name.characters.first,
              style: GoogleFonts.poppins(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _ReelActionsSheet extends StatelessWidget {
  const _ReelActionsSheet({
    required this.reel,
    required this.onEdit,
    required this.onBoost,
    required this.onDelete,
  });

  final _CookReelItem reel;
  final VoidCallback onEdit;
  final VoidCallback onBoost;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 18),
          _SheetActionTile(
            icon: Icons.edit_rounded,
            title: reel.isMine ? 'Edit Reel' : 'View Cook',
            onTap: onEdit,
          ),
          _SheetActionTile(
            icon: Icons.trending_up_rounded,
            title: 'Promote Reel',
            onTap: onBoost,
          ),
          _SheetActionTile(
            icon: Icons.delete_outline_rounded,
            title: reel.isMine ? 'Delete Reel' : 'Report Reel',
            color: AppColors.error,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _MyReelActionsSheet extends StatelessWidget {
  const _MyReelActionsSheet({
    required this.reel,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  final _MyCookReel reel;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 18),
          _SheetActionTile(
            icon: Icons.edit_rounded,
            title: reel.isDraft ? 'Edit Draft' : 'Edit Reel',
            onTap: onEdit,
          ),
          _SheetActionTile(
            icon: reel.isDraft
                ? Icons.cloud_upload_outlined
                : Icons.visibility_outlined,
            title: reel.isDraft ? 'Publish Reel' : 'View Insights',
            onTap: onPublish,
          ),
          _SheetActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Reel',
            color: AppColors.error,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CreateReelSheet extends StatelessWidget {
  const _CreateReelSheet({
    required this.onPickVideo,
    required this.onRecordVideo,
  });

  final VoidCallback onPickVideo;
  final VoidCallback onRecordVideo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 18),
          Text(
            'Create Reel',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a short cooking clip for customers and other cooks.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _SheetActionTile(
            icon: Icons.video_library_outlined,
            title: 'Upload from gallery',
            onTap: onPickVideo,
          ),
          _SheetActionTile(
            icon: Icons.videocam_outlined,
            title: 'Record new reel',
            onTap: onRecordVideo,
          ),
        ],
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: AppColors.homeChrome.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.homeDivider,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CookReelItem {
  const _CookReelItem({
    required this.id,
    required this.creatorId,
    this.imageUrl,
    required this.creatorName,
    this.creatorImageUrl,
    required this.description,
    required this.audioLabel,
    required this.likes,
    required this.comments,
    this.commentItems = const [],
    required this.shares,
    required this.isMine,
    this.isFollowing = false,
    this.isLiked = false,
    this.isPaused = true,
    this.isBookmarked = false,
    this.videoPath,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String? imageUrl;
  final String creatorName;
  final String? creatorImageUrl;
  final String description;
  final String audioLabel;
  final int likes;
  final int comments;
  final int shares;
  final List<ReelCommentModel> commentItems;
  final bool isMine;
  final bool isFollowing;
  final bool isLiked;
  final bool isPaused;
  final bool isBookmarked;
  final String? videoPath;
  final DateTime createdAt;

  _CookReelItem copyWith({
    String? id,
    String? creatorId,
    String? imageUrl,
    String? creatorName,
    String? creatorImageUrl,
    String? description,
    String? audioLabel,
    int? likes,
    int? comments,
    List<ReelCommentModel>? commentItems,
    int? shares,
    bool? isMine,
    bool? isFollowing,
    bool? isLiked,
    bool? isPaused,
    bool? isBookmarked,
    String? videoPath,
    DateTime? createdAt,
  }) {
    return _CookReelItem(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorName: creatorName ?? this.creatorName,
      creatorImageUrl: creatorImageUrl ?? this.creatorImageUrl,
      description: description ?? this.description,
      audioLabel: audioLabel ?? this.audioLabel,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      commentItems: commentItems ?? this.commentItems,
      shares: shares ?? this.shares,
      isMine: isMine ?? this.isMine,
      isFollowing: isFollowing ?? this.isFollowing,
      isLiked: isLiked ?? this.isLiked,
      isPaused: isPaused ?? this.isPaused,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videoPath: videoPath ?? this.videoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  CookReelModel toCookReelModel() {
    return CookReelModel(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorImageUrl: creatorImageUrl,
      title: description,
      description: description,
      imageUrl: imageUrl,
      videoPath: videoPath ?? '',
      audioLabel: audioLabel,
      likes: likes,
      comments: comments,
      shares: shares,
      isMine: isMine,
      isFollowing: isFollowing,
      isLiked: isLiked,
      isPaused: isPaused,
      isBookmarked: isBookmarked,
      isDraft: false,
      commentItems: commentItems,
      createdAt: createdAt,
    );
  }
}

class _MyCookReel {
  const _MyCookReel({
    required this.id,
    required this.creatorName,
    required this.title,
    required this.audioLabel,
    required this.ageLabel,
    required this.views,
    required this.comments,
    this.imageUrl,
    this.videoPath,
    this.isDraft = false,
  });

  final String id;
  final String creatorName;
  final String title;
  final String audioLabel;
  final String ageLabel;
  final int views;
  final int comments;
  final String? imageUrl;
  final String? videoPath;
  final bool isDraft;

  _MyCookReel copyWith({
    String? id,
    String? creatorName,
    String? title,
    String? audioLabel,
    String? ageLabel,
    int? views,
    int? comments,
    String? imageUrl,
    String? videoPath,
    bool? isDraft,
  }) {
    return _MyCookReel(
      id: id ?? this.id,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      audioLabel: audioLabel ?? this.audioLabel,
      ageLabel: ageLabel ?? this.ageLabel,
      views: views ?? this.views,
      comments: comments ?? this.comments,
      imageUrl: imageUrl ?? this.imageUrl,
      videoPath: videoPath ?? this.videoPath,
      isDraft: isDraft ?? this.isDraft,
    );
  }
}

String _compactNumber(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    final text =
        compact >= 10 ? compact.toStringAsFixed(0) : compact.toStringAsFixed(1);
    return '${text.replaceAll('.0', '')}k';
  }
  return '$value';
}

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final path = imageUrl?.trim() ?? '';
    final fallbackAsset = _defaultAvatarAssetFor(name);

    Widget imageWidget;
    if (path.isEmpty) {
      imageWidget = Image.asset(fallbackAsset, fit: BoxFit.cover);
    } else if (path.startsWith('assets/')) {
      imageWidget = Image.asset(path, fit: BoxFit.cover);
    } else if (File(path).existsSync()) {
      imageWidget = Image.file(File(path), fit: BoxFit.cover);
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.homeDivider.withValues(alpha: 0.3),
        ),
        errorWidget: (context, url, error) => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 31,
      height: 31,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: imageWidget),
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
