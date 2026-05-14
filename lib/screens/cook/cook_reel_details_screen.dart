import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/services/reel_service.dart';
import 'package:naham_app/widgets/reel_video_surface.dart';
import 'package:provider/provider.dart';

class CookReelDetailsScreen extends StatefulWidget {
  const CookReelDetailsScreen({
    super.key,
    required this.videoPath,
  });

  final String videoPath;

  @override
  State<CookReelDetailsScreen> createState() => _CookReelDetailsScreenState();
}

class _CookReelDetailsScreenState extends State<CookReelDetailsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublishing = false;
  double _uploadProgress = 0;
  String _statusMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _publishReel() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      _showSnack('Please enter a video title.');
      return;
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      _showSnack('You must sign in first.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _statusMessage = 'Preparing upload...';
    });

    final reelId = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = 'reel_$reelId.mp4';

    try {
      // 1. Upload Video
      setState(() => _statusMessage = 'Uploading video...');
      final videoUrl = await ReelService.instance.uploadVideoFile(
        widget.videoPath,
        reelId,
        fileName,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
            _statusMessage = 'Uploaded ${(progress * 100).toStringAsFixed(0)}%';
          });
        },
      );

      // 2. Save Metadata
      setState(() => _statusMessage = 'Saving details...');
      final reel = CookReelModel(
        id: reelId,
        creatorId: currentUser.id,
        creatorName: _resolveCreatorName(currentUser),
        creatorImageUrl: currentUser.profileImageUrl,
        title: title,
        description: description.isNotEmpty
            ? description
            : 'Short cooking clip from your kitchen.',
        imageUrl: null,
        videoPath: videoUrl,
        audioLabel: 'Original Audio - Naham Cook',
        likes: 0,
        comments: 0,
        shares: 0,
        isMine: true,
        isFollowing: false,
        isLiked: false,
        isPaused: false,
        isBookmarked: false,
        isDraft: false,
        createdAt: DateTime.now(),
      );

      await ReelService.instance.saveReel(reel);

      // 3. Clean up the temporary video file
      try {
        final file = File(widget.videoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete temp video file: $e');
      }

      if (!mounted) return;
      _showSnack('Video published successfully.');

      // Navigate back to reels list
      context.go(AppRoutes.cookReels);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      _showSnack('Publishing failed: ${error.toString()}');
    }
  }

  String _resolveCreatorName(UserModel user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return '@$displayName';
    }
    final name = user.name.trim();
    return name.isNotEmpty ? '@$name' : '@cook';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Video Details',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isPublishing ? null : () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Video Preview
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ReelVideoSurface(
                    source: widget.videoPath,
                    isPaused: false,
                  ),
                ),
                const SizedBox(height: 24),

                // Title Field
                Text(
                  'Video Title',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  enabled: !_isPublishing,
                  decoration: InputDecoration(
                    hintText: 'Example: How to prepare Najdi kabsa',
                    hintStyle: GoogleFonts.cairo(
                        fontSize: 14, color: AppColors.textHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.cairo(fontSize: 15),
                ),
                const SizedBox(height: 20),

                // Description Field
                Text(
                  'Video Description (optional)',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  enabled: !_isPublishing,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a short description for your followers...',
                    hintStyle: GoogleFonts.cairo(
                        fontSize: 14, color: AppColors.textHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.cairo(fontSize: 15),
                ),
                const SizedBox(height: 32),

                // Publish Button
                ElevatedButton(
                  onPressed: _isPublishing ? null : _publishReel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.homeDeliveryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Publish Video',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Upload Overlay
          if (_isPublishing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        strokeWidth: 6,
                        color: AppColors.homeDeliveryGreen,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_uploadProgress > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            color: AppColors.homeDeliveryGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
