import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:naham_app/services/aws/aws_dish_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';
import 'package:provider/provider.dart';

const String _cookMaleAvatarAsset =
    'assets/images/default_male_profile_image.png';
const String _cookFemaleAvatarAsset =
    'assets/images/default_female_profile_image.png';

class CookProfileScreen extends StatefulWidget {
  const CookProfileScreen({super.key});

  @override
  State<CookProfileScreen> createState() => _CookProfileScreenState();
}

class _CookProfileScreenState extends State<CookProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _cookNameController = TextEditingController();
  final _kitchenNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isEditing = false;
  bool _didSeedForm = false;
  bool _isSaving = false;
  bool _hasRequestedBackendRefresh = false;
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestBackendProfileRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seedFromCurrentUser();
    _requestBackendProfileRefresh();
  }

  @override
  void dispose() {
    _cookNameController.dispose();
    _kitchenNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _seedFromCurrentUser({bool force = false}) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    if (!_didSeedForm || force) {
      _cookNameController.text = user.name.isNotEmpty ? user.name : '';
      _kitchenNameController.text = _resolveKitchenName(user);
      _phoneController.text = user.phone.isNotEmpty ? user.phone : '';
      _locationController.text = _normalizeRegion(user.address);
      _selectedAvatarPath = user.profileImageUrl;
      _didSeedForm = true;
    } else {
      // Logic for background sync/refresh
      if (!_isEditing) {
        final backendRegion = _normalizeRegion(user.address);
        if (backendRegion.isNotEmpty &&
            _locationController.text != backendRegion) {
          _locationController.text = backendRegion;
        }
      }
      final backendUrl = user.profileImageUrl;
      if (backendUrl != null) {
        // If we don't have a selection, or our selection is an old URL, sync with backend
        if (_selectedAvatarPath == null ||
            _selectedAvatarPath!.startsWith('http')) {
          if (_selectedAvatarPath != backendUrl) {
            _selectedAvatarPath = backendUrl;
          }
        }
      }
    }
  }

  String _normalizeRegion(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return AppConstants.saudiRegions.contains(trimmed) ? trimmed : '';
  }

  String _resolveKitchenName(UserModel user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    if (user.name.trim().isEmpty) {
      return '';
    }

    final trimmedName = user.name.trim();
    if (trimmedName.toLowerCase().contains('kitchen')) {
      return trimmedName;
    }
    return "$trimmedName's Kitchen";
  }

  String _resolvedAvatarPath(UserModel user, {String? draftPath}) {
    final candidate = draftPath ?? user.profileImageUrl;
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return _defaultAvatarAssetFor(user);
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
        return _cookFemaleAvatarAsset;
      }
    }

    return _cookMaleAvatarAsset;
  }

  double? _resolvedRating(UserModel user) {
    final rating = user.rating;
    if (rating == null || rating <= 0) {
      return null;
    }
    return rating;
  }

  bool _isVerified(UserModel user) {
    return user.cookStatus == AppConstants.cookApproved;
  }

  void _enterEditMode() {
    _seedFromCurrentUser(force: true);
    setState(() {
      _isEditing = true;
    });
  }

  void _exitEditMode() {
    _seedFromCurrentUser(force: true);
    context.read<AuthProvider>().clearError();
    setState(() {
      _isEditing = false;
      _isSaving = false;
    });
  }

  void _requestBackendProfileRefresh() {
    final user = context.read<AuthProvider>().currentUser;
    if (!mounted || _isEditing || user == null || _hasRequestedBackendRefresh) {
      return;
    }

    _hasRequestedBackendRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isEditing) return;
      final auth = context.read<AuthProvider>();
      final refreshed = await auth.refreshCurrentUser();
      if (!mounted || !refreshed) return;
      _seedFromCurrentUser(force: true);
      setState(() {});
    });
  }

  Future<void> _openAvatarPicker() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CookSheetHandle(),
                  const SizedBox(height: 18),
                  Text(
                    'Change profile photo',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick any image from your gallery or use a default avatar.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CookActionTile(
                    icon: Icons.photo_library_outlined,
                    iconBackground: const Color(0xFFF2ECFF),
                    iconColor: AppColors.homeChrome,
                    title: 'Choose from gallery',
                    subtitle: 'Use any photo from your phone',
                    onTap: () => Navigator.of(context).pop('gallery'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CookAvatarChoiceTile(
                          label: 'Male avatar',
                          assetPath: _cookMaleAvatarAsset,
                          isSelected:
                              _selectedAvatarPath == _cookMaleAvatarAsset,
                          onTap: () =>
                              Navigator.of(context).pop(_cookMaleAvatarAsset),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CookAvatarChoiceTile(
                          label: 'Female avatar',
                          assetPath: _cookFemaleAvatarAsset,
                          isSelected:
                              _selectedAvatarPath == _cookFemaleAvatarAsset,
                          onTap: () =>
                              Navigator.of(context).pop(_cookFemaleAvatarAsset),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_selectedAvatarPath != null)
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: Text(
                          'Use automatic default',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.homeChrome,
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

    if (!mounted || selected == null) {
      return;
    }

    if (selected == 'gallery') {
      await _pickAvatarFromGallery();
      return;
    }

    setState(() {
      _selectedAvatarPath = selected.isEmpty ? null : selected;
    });
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 900,
      );

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _selectedAvatarPath = image.path;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Unable to open gallery. Please try again.');
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    String? imageUrlToSave = _selectedAvatarPath;

    // If the selected image is a local file (from gallery), upload it to S3
    // first so we persist a public URL, not a temporary local path.
    if (imageUrlToSave != null &&
        !imageUrlToSave.startsWith('http') &&
        !imageUrlToSave.startsWith('assets/')) {
      try {
        final file = File(imageUrlToSave);
        if (await file.exists()) {
          final userId = auth.currentUser?.id ?? 'unknown';
          final uploaded = await _uploadProfileImage(file, userId);
          if (uploaded != null) {
            // Append a timestamp to the URL to bust the local image cache.
            imageUrlToSave =
                '$uploaded?t=${DateTime.now().millisecondsSinceEpoch}';
            _selectedAvatarPath = imageUrlToSave;
          }
        }
      } catch (e) {
        debugPrint('Profile image upload failed: $e');
        if (!mounted) return;
        _showSnack('Failed to upload profile image. Please try again.');
        setState(() => _isSaving = false);
        return;
      }
    }

    final success = await auth.updateProfile(
      name: _cookNameController.text.trim(),
      displayName: _kitchenNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _locationController.text.trim(),
      profileImageUrl: imageUrlToSave,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!success) {
      return;
    }

    auth.clearError();
    setState(() {
      _isEditing = false;
    });
    _showSnack('Profile updated successfully.');
  }

  /// Uploads a local image file to S3 using the dishes upload-url endpoint
  /// and returns the public URL. Returns null on failure.
  Future<String?> _uploadProfileImage(File imageFile, String userId) async {
    // Use the dish upload infrastructure with a profile-specific key.
    final awsService = AwsDishService(
      apiClient: BackendFactory.createAwsDishesApiClient(),
    );
    final result = await awsService.uploadImage(
      imageFile,
      'profile_$userId',
    );
    return result['fileUrl'];
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Logout?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You will need to sign in again to access your kitchen account.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.login);
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

  void _showDocumentsSheet(UserModel _) {
    _openReportsScreen();
  }

  void _openHygieneHistoryScreen() {
    context.push(AppRoutes.cookHygieneHistory);
  }

  void _openReportsScreen() {
    context.push(AppRoutes.cookReports);
  }

  void _handleBottomNavTap(int index) {
    if (index == 5) return;
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
    if (index == 4) {
      context.go(AppRoutes.myMenu);
      return;
    }
    if (index == 3) {
      context.go(AppRoutes.cookChat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      _requestBackendProfileRefresh();
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Center(
          child: Text(
            'Profile is unavailable.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final avatarPath = _resolvedAvatarPath(
      user,
      draftPath: _selectedAvatarPath,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Column(
          children: [
            _CookProfileTopBar(
              isEditing: _isEditing,
              showWarning: !_isVerified(user),
              onBackTap: _exitEditMode,
              onWarningTap: () => _showDocumentsSheet(user),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isEditing
                    ? _CookProfileEditView(
                        key: const ValueKey('cook-edit-profile'),
                        formKey: _formKey,
                        cookNameController: _cookNameController,
                        kitchenNameController: _kitchenNameController,
                        phoneController: _phoneController,
                        locationController: _locationController,
                        avatarPath: avatarPath,
                        fallbackAvatarPath: _defaultAvatarAssetFor(user),
                        isSaving: _isSaving,
                        errorMessage: auth.errorMessage,
                        onChangePhotoTap: _openAvatarPicker,
                        onSaveTap: _saveProfile,
                      )
                    : _CookProfileOverview(
                        key: const ValueKey('cook-profile-overview'),
                        user: user,
                        avatarPath: avatarPath,
                        fallbackAvatarPath: _defaultAvatarAssetFor(user),
                        rating: _resolvedRating(user),
                        isVerified: _isVerified(user),
                        onAvatarTap: _openAvatarPicker,
                        onEditTap: _enterEditMode,
                        onDocumentsTap: () => _showDocumentsSheet(user),
                        onHealthVerificationTap: _openHygieneHistoryScreen,
                        onLogoutTap: _confirmLogout,
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 5,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }
}

class _CookProfileTopBar extends StatelessWidget {
  const _CookProfileTopBar({
    required this.isEditing,
    required this.showWarning,
    required this.onBackTap,
    required this.onWarningTap,
  });

  final bool isEditing;
  final bool showWarning;
  final VoidCallback onBackTap;
  final VoidCallback onWarningTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isEditing
                  ? IconButton(
                      onPressed: onBackTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    )
                  : SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.asset(
                        'assets/naham_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Text(
              isEditing ? 'Edit Profile' : 'My Profile',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: !isEditing && showWarning
                  ? IconButton(
                      onPressed: onWarningTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        size: 27,
                        color: Color(0xFFFFE043),
                      ),
                    )
                  : const SizedBox(width: 28, height: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _CookProfileOverview extends StatelessWidget {
  const _CookProfileOverview({
    super.key,
    required this.user,
    required this.avatarPath,
    required this.fallbackAvatarPath,
    required this.rating,
    required this.isVerified,
    required this.onAvatarTap,
    required this.onEditTap,
    required this.onDocumentsTap,
    required this.onHealthVerificationTap,
    required this.onLogoutTap,
  });

  final UserModel user;
  final String avatarPath;
  final String fallbackAvatarPath;
  final double? rating;
  final bool isVerified;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onHealthVerificationTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final kitchenName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : "${user.name.trim().isEmpty ? 'Cook' : user.name.trim()}'s Kitchen";

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.homeCardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              _CookProfileAvatar(
                imagePath: avatarPath,
                fallbackAssetPath: fallbackAvatarPath,
                size: 94,
                badgeColor: const Color(0xFF0FA84A),
                badgeIcon: Icons.camera_alt_rounded,
                onBadgeTap: onAvatarTap,
              ),
              const SizedBox(height: 10),
              if (user.name.trim().isNotEmpty) ...[
                Text(
                  user.name.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              if (kitchenName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  kitchenName,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2E3B32),
                  ),
                ),
              ],
              const SizedBox(height: 7),
              if ((user.address ?? '').trim().isEmpty) ...[
                const SizedBox(height: 10),
                const _CookMissingRegionWarning(
                  message:
                      'You have not selected your region yet. Customers will not be able to order from you until your service region is set.',
                ),
              ],
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    5,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: 1),
                      child: Icon(
                        Icons.star_rounded,
                        size: 17,
                        color: rating == null
                            ? const Color(0xFFD6DAE2)
                            : index < rating!.round().clamp(0, 5)
                                ? const Color(0xFFF9B404)
                                : const Color(0xFFD6DAE2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    rating == null
                        ? 'No ratings yet'
                        : rating!.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.homeDivider, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CookProfileStat(
                      value: (user.totalOrders ?? 0).toString(),
                      label: 'TOTAL',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.homeDivider,
                  ),
                  Expanded(
                    child: _CookProfileStat(
                      value: user.currentMonthOrders.toString(),
                      label: 'MONTH',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.homeDivider,
                  ),
                  Expanded(
                    child: _CookProfileStat(
                      value: user.followersCount.toString(),
                      label: 'FOLLOWERS',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.homeDivider,
                  ),
                  Expanded(
                    child: _CookProfileStat(
                      value: user.reelLikesCount.toString(),
                      label: 'LIKES',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── Online Status & Working Hours ──
        _CookLiveStatusCard(user: user),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ACCOUNT',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA4A8B1),
            ),
          ),
        ),
        _CookSectionCard(
          children: [
            _CookSectionRow(
              icon: Icons.person_outline_rounded,
              iconBackground: const Color(0xFFF3ECFF),
              iconColor: AppColors.homeChrome,
              title: 'Edit Profile',
              subtitle: 'Name, phone, location, working\nhours',
              onTap: onEditTap,
            ),
            _CookSectionRow(
              icon: Icons.description_outlined,
              iconBackground: const Color(0xFFEAF2FF),
              iconColor: const Color(0xFF4F82FF),
              title: 'Documents',
              subtitle: 'ID, licenses, certificates',
              trailing: _CookStatusBadge(
                label: isVerified ? 'Verified' : 'Pending',
                color: isVerified
                    ? const Color(0xFFEDE8FF)
                    : const Color(0xFFFFF4D9),
                textColor:
                    isVerified ? AppColors.homeChrome : const Color(0xFFB38100),
              ),
              onTap: onDocumentsTap,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BUSINESS',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA4A8B1),
            ),
          ),
        ),
        _CookSectionCard(
          children: [
            _CookSectionRow(
              icon: Icons.health_and_safety_outlined,
              iconBackground: const Color(0xFFFFEDEF),
              iconColor: const Color(0xFFEC5A63),
              title: 'Health Verification',
              subtitle: 'Inspection history & status',
              onTap: onHealthVerificationTap,
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onLogoutTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: Color(0xFFFFD4D8)),
            backgroundColor: const Color(0xFFFFF5F6),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            'Logout',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _CookSectionCard extends StatelessWidget {
  const _CookSectionCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index != children.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F1F5),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _CookLiveStatusCard extends StatelessWidget {
  const _CookLiveStatusCard({required this.user});

  final UserModel user;

  static const List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  static const List<String> _dayShort = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  int get _todayIndex => DateTime.now().weekday % 7;

  String _timeFor(String day) {
    final wh = user.workingHours;
    if (wh == null) return 'Not set';
    final slot = wh[day];
    if (slot == null || slot is! Map<String, dynamic>) return 'Not set';
    if (slot['isActive'] != true) return 'Closed';
    final s = slot['start'] as int?;
    final e = slot['end'] as int?;
    if (s == null || e == null) return 'Not set';
    return '${_fmt(s)} – ${_fmt(e)}';
  }

  static String _fmt(int m) {
    final h24 = m ~/ 60;
    final mm = m % 60;
    final pm = h24 >= 12;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${mm.toString().padLeft(2, '0')} ${pm ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = user.isOnline == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.homeCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF2EA05B)
                      : const Color(0xFFCCCCCC),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isOnline
                      ? const Color(0xFF2EA05B)
                      : const Color(0xFF999999),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFFDFF6E7)
                      : const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOnline ? 'On Shift' : 'Off Shift',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isOnline
                        ? const Color(0xFF2EA05B)
                        : const Color(0xFFB38100),
                  ),
                ),
              ),
              const Spacer(),
              if (user.dailyCapacity != null)
                Text(
                  '${user.dailyCapacity} dishes/day',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF999FAA),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F1F5), height: 1),
          const SizedBox(height: 12),
          Text(
            'Weekly Schedule',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_days.length, (i) {
            final isToday = i == _todayIndex;
            final time = _timeFor(_days[i]);
            final isClosed = time == 'Closed' || time == 'Not set';
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isToday ? const Color(0xFFF1DFFF) : const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(6),
                border:
                    isToday ? Border.all(color: const Color(0xFFE0B7FF)) : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      _dayShort[i],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? const Color(0xFF8C39BB)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      time,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        color: isClosed
                            ? const Color(0xFFBBBBBB)
                            : isToday
                                ? const Color(0xFF8C39BB)
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA51FFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Today',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CookSectionRow extends StatelessWidget {
  const _CookSectionRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 6),
                          trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFFAFB5C2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookProfileEditView extends StatelessWidget {
  const _CookProfileEditView({
    super.key,
    required this.formKey,
    required this.cookNameController,
    required this.kitchenNameController,
    required this.phoneController,
    required this.locationController,
    required this.avatarPath,
    required this.fallbackAvatarPath,
    required this.isSaving,
    required this.errorMessage,
    required this.onChangePhotoTap,
    required this.onSaveTap,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController cookNameController;
  final TextEditingController kitchenNameController;
  final TextEditingController phoneController;
  final TextEditingController locationController;
  final String avatarPath;
  final String fallbackAvatarPath;
  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onChangePhotoTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              children: [
                Column(
                  children: [
                    _CookProfileAvatar(
                      imagePath: avatarPath,
                      fallbackAssetPath: fallbackAvatarPath,
                      size: 96,
                      badgeColor: const Color(0xFFD7C4FF),
                      badgeIcon: Icons.camera_alt_rounded,
                      badgeIconColor: Colors.white,
                      onBadgeTap: onChangePhotoTap,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onChangePhotoTap,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        'Change Photo',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.homeChrome,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CookEditSectionCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Basic Information',
                  child: Column(
                    children: [
                      _CookLabeledField(
                        label: 'Cook Name',
                        controller: cookNameController,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Please enter a valid cook name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _CookLabeledField(
                        label: 'Kitchen Name',
                        controller: kitchenNameController,
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Please enter a kitchen name.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _CookEditSectionCard(
                  icon: Icons.phone_outlined,
                  title: 'Contact Information',
                  child: Column(
                    children: [
                      _CookLabeledField(
                        label: 'Phone Number',
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().length < 7) {
                            return 'Please enter a valid phone number.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _CookRegionDropdownField(
                        label: 'Region',
                        controller: locationController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select your region.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : onSaveTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.homeChrome,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CookEditSectionCard extends StatelessWidget {
  const _CookEditSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.homeCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.homeChrome),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _CookLabeledField extends StatelessWidget {
  const _CookLabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F4F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.homeChrome,
                width: 1.2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _CookRegionDropdownField extends StatelessWidget {
  const _CookRegionDropdownField({
    required this.label,
    required this.controller,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final currentValue = AppConstants.saudiRegions.contains(controller.text)
        ? controller.text
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: currentValue,
          items: AppConstants.saudiRegions
              .map(
                (region) => DropdownMenuItem<String>(
                  value: region,
                  child: Text(region),
                ),
              )
              .toList(),
          onChanged: (value) {
            controller.text = value ?? '';
          },
          validator: validator,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F4F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.homeChrome,
                width: 1.2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _CookMissingRegionWarning extends StatelessWidget {
  const _CookMissingRegionWarning({required this.message});

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

class _CookProfileStat extends StatelessWidget {
  const _CookProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _CookActionTile extends StatelessWidget {
  const _CookActionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.homeCardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAFB5C2),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookStatusBadge extends StatelessWidget {
  const _CookStatusBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _CookAvatarChoiceTile extends StatelessWidget {
  const _CookAvatarChoiceTile({
    required this.label,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.homeChrome.withValues(alpha: 0.1)
              : AppColors.homeMintSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.homeChrome : AppColors.homeCardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            ClipOval(
              child: Image.asset(
                assetPath,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookProfileAvatar extends StatelessWidget {
  const _CookProfileAvatar({
    required this.imagePath,
    required this.fallbackAssetPath,
    required this.size,
    required this.badgeColor,
    required this.badgeIcon,
    required this.onBadgeTap,
    this.badgeIconColor = Colors.white,
  });

  final String imagePath;
  final String fallbackAssetPath;
  final double size;
  final Color badgeColor;
  final IconData badgeIcon;
  final VoidCallback onBadgeTap;
  final Color badgeIconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.homeDivider, width: 1.5),
              ),
              child: ClipOval(child: _buildImage()),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onBadgeTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(badgeIcon, size: 18, color: badgeIconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final path = imagePath.trim();
    if (path.isEmpty) {
      return Image.asset(fallbackAssetPath, fit: BoxFit.cover);
    }

    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }

    // Check if it's a local file (e.g. from picker)
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Image.asset(fallbackAssetPath, fit: BoxFit.cover),
        );
      }
    } catch (_) {
      // Not a valid file path or access denied
    }

    // Treat everything else as a network image (S3 URL, etc.)
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppColors.homeDivider.withValues(alpha: 0.5),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Image.asset(
        fallbackAssetPath,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _CookSheetHandle extends StatelessWidget {
  const _CookSheetHandle();

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
