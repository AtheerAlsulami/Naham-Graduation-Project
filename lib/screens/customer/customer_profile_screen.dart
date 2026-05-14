import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/services/aws/aws_dish_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';
import 'package:provider/provider.dart';

const String _maleAvatarAsset = 'assets/images/default_male_profile_image.png';
const String _femaleAvatarAsset =
    'assets/images/default_female_profile_image.png';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.isEditing,
    required this.onEditRequested,
    required this.onEditClosed,
    required this.onSupportChatRequested,
  });

  final bool isEditing;
  final VoidCallback onEditRequested;
  final VoidCallback onEditClosed;
  final VoidCallback onSupportChatRequested;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  bool _didSeedForm = false;
  bool _isSaving = false;
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isEditing) return;
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seedFromCurrentUser();
  }

  @override
  void didUpdateWidget(covariant CustomerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      _seedFromCurrentUser(force: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _seedFromCurrentUser({bool force = false}) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || (_didSeedForm && !force)) {
      return;
    }

    _nameController.text = user.name.isNotEmpty ? user.name : '';
    _displayNameController.text = _resolveInitialDisplayName(user);
    _phoneController.text = user.phone.isNotEmpty ? user.phone : '';
    _locationController.text = _normalizeRegion(user.address);
    _selectedAvatarPath = user.profileImageUrl;
    _didSeedForm = true;
  }

  String _normalizeRegion(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return AppConstants.saudiRegions.contains(trimmed) ? trimmed : '';
  }

  String _resolveInitialDisplayName(UserModel user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    if (user.role == AppConstants.roleCook) {
      return "${user.name}'s Kitchen";
    }

    return user.name;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.homeDivider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choose profile image',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose any image from your gallery or use one of the default avatars.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GalleryImageTile(
                    onTap: () => Navigator.of(context).pop('gallery'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _AvatarChoiceTile(
                          label: 'Male avatar',
                          assetPath: _maleAvatarAsset,
                          isSelected: _selectedAvatarPath == _maleAvatarAsset,
                          onTap: () =>
                              Navigator.of(context).pop(_maleAvatarAsset),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AvatarChoiceTile(
                          label: 'Female avatar',
                          assetPath: _femaleAvatarAsset,
                          isSelected: _selectedAvatarPath == _femaleAvatarAsset,
                          onTap: () =>
                              Navigator.of(context).pop(_femaleAvatarAsset),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedAvatarPath != null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: Text(
                          'Use automatic default',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.authButtonEnd,
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
      name: _nameController.text.trim(),
      displayName: _displayNameController.text.trim(),
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
    widget.onEditClosed();
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
            'You will need to sign in again to access your account.',
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

  Future<void> _openFavoritesSheet() async {
    final dishProvider = context.read<DishProvider>();
    final favorites = dishProvider.customerDishes.take(4).toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.homeDivider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Favorites',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your liked dishes are ready for quick reorder.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final dish = favorites[index];
                    return _FavoriteDishTile(
                      dish: dish,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('${AppRoutes.dishDetail}/${dish.id}');
                      },
                      onAddTap: () => _addDishToCart(dish),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addDishToCart(DishModel dish) async {
    final cart = context.read<CartProvider>();

    if (cart.items.isNotEmpty && cart.currentCookId != dish.cookId) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Replace current cart?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Your cart contains dishes from another cook. Adding ${dish.name} will clear it first.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );

      if (shouldReplace != true || !mounted) {
        return;
      }

      cart.clearCart();
    }

    cart.addItem(dish, 1);
    if (!mounted) {
      return;
    }

    _showSnack('${dish.name} added to cart');
    context.push(AppRoutes.cart);
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
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          'Profile is unavailable.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: widget.isEditing
          ? _EditProfileView(
              key: const ValueKey('edit-profile'),
              formKey: _formKey,
              user: user,
              nameController: _nameController,
              displayNameController: _displayNameController,
              phoneController: _phoneController,
              locationController: _locationController,
              selectedAvatarPath:
                  _resolvedAvatarPath(user, draftPath: _selectedAvatarPath),
              fallbackAvatarPath: _defaultAvatarAssetFor(user),
              isSaving: _isSaving,
              errorMessage: auth.errorMessage,
              onChangePhotoTap: _openAvatarPicker,
              onSaveTap: _saveProfile,
            )
          : _ProfileOverview(
              key: const ValueKey('profile-overview'),
              user: user,
              avatarPath: _resolvedAvatarPath(user),
              fallbackAvatarPath: _defaultAvatarAssetFor(user),
              onAvatarTap: _openAvatarPicker,
              onEditTap: widget.onEditRequested,
              onFavoritesTap: _openFavoritesSheet,
              onSupportTap: widget.onSupportChatRequested,
              onLogoutTap: _confirmLogout,
            ),
    );
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
        return _femaleAvatarAsset;
      }
    }

    return _maleAvatarAsset;
  }
}

class CustomerProfileTopBar extends StatelessWidget {
  const CustomerProfileTopBar({
    super.key,
    required this.isEditing,
    required this.onBackTap,
  });

  final bool isEditing;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
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
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({
    super.key,
    required this.user,
    required this.avatarPath,
    required this.fallbackAvatarPath,
    required this.onAvatarTap,
    required this.onEditTap,
    required this.onFavoritesTap,
    required this.onSupportTap,
    required this.onLogoutTap,
  });

  final UserModel user;
  final String avatarPath;
  final String fallbackAvatarPath;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onSupportTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.homeCardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: Column(
            children: [
              _ProfileAvatar(
                imagePath: avatarPath,
                fallbackAssetPath: fallbackAvatarPath,
                size: 92,
                badgeColor: AppColors.success,
                onBadgeTap: onAvatarTap,
                badgeIcon: Icons.camera_alt_rounded,
              ),
              const SizedBox(height: 14),
              Text(
                user.name.isNotEmpty ? user.name : 'Customer',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Member since ${user.createdAt.year}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.0,
                ),
              ),
              if ((user.address ?? '').trim().isEmpty) ...[
                const SizedBox(height: 14),
                const _MissingRegionWarning(
                  message:
                      'You have not selected your region yet. Orders may fail until your delivery region is set.',
                ),
              ],
              const SizedBox(height: 18),
              const Divider(color: AppColors.homeDivider),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      value: user.ordersPlacedCount.toString(),
                      label: 'ORDERS',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: AppColors.homeDivider,
                  ),
                  Expanded(
                    child: _ProfileStat(
                      value: user.likedReelsCount.toString(),
                      label: 'LIKES',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: AppColors.homeDivider,
                  ),
                  Expanded(
                    child: _ProfileStat(
                      value: user.followingCooksCount.toString(),
                      label: 'FOLLOWING',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ProfileMenuTile(
          icon: Icons.person_outline_rounded,
          iconBackground: const Color(0xFFF0E4FF),
          iconColor: AppColors.authButtonEnd,
          title: 'Edit Profile',
          subtitle: user.role == AppConstants.roleCook
              ? 'Name, phone, location, kitchen details'
              : 'Name, phone, location, display name',
          onTap: onEditTap,
        ),
        const SizedBox(height: 14),
        _ProfileMenuTile(
          icon: Icons.favorite_rounded,
          iconBackground: const Color(0xFFFFF0BD),
          iconColor: const Color(0xFFFF4F5E),
          title: 'Favorites',
          subtitle: 'likes',
          onTap: onFavoritesTap,
        ),
        const SizedBox(height: 14),
        _ProfileMenuTile(
          icon: Icons.settings_rounded,
          iconBackground: const Color(0xFFE7E7E7),
          iconColor: const Color(0xFF666666),
          title: 'Support',
          subtitle: 'chat with our admins',
          onTap: onSupportTap,
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onLogoutTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFCFCF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Color(0xFFFF4747),
                ),
                const SizedBox(width: 10),
                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF4747),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProfileView extends StatelessWidget {
  const _EditProfileView({
    super.key,
    required this.formKey,
    required this.user,
    required this.nameController,
    required this.displayNameController,
    required this.phoneController,
    required this.locationController,
    required this.selectedAvatarPath,
    required this.fallbackAvatarPath,
    required this.isSaving,
    required this.errorMessage,
    required this.onChangePhotoTap,
    required this.onSaveTap,
  });

  final GlobalKey<FormState> formKey;
  final UserModel user;
  final TextEditingController nameController;
  final TextEditingController displayNameController;
  final TextEditingController phoneController;
  final TextEditingController locationController;
  final String selectedAvatarPath;
  final String fallbackAvatarPath;
  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onChangePhotoTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    final primaryNameLabel =
        user.role == AppConstants.roleCook ? 'Cook Name' : 'Full Name';
    final secondaryNameLabel =
        user.role == AppConstants.roleCook ? 'Kitchen Name' : 'Display Name';

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            children: [
              Center(
                child: Column(
                  children: [
                    _ProfileAvatar(
                      imagePath: selectedAvatarPath,
                      fallbackAssetPath: fallbackAvatarPath,
                      size: 96,
                      badgeColor: AppColors.homeChrome,
                      onBadgeTap: onChangePhotoTap,
                      badgeIcon: Icons.camera_alt_rounded,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onChangePhotoTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.homeChrome,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Change Photo',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    _EditSectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Basic Information',
                      child: Column(
                        children: [
                          _LabeledField(
                            label: primaryNameLabel,
                            controller: nameController,
                            validator: (value) {
                              if (value == null || value.trim().length < 3) {
                                return 'Please enter a valid name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _LabeledField(
                            label: secondaryNameLabel,
                            controller: displayNameController,
                            validator: (value) {
                              if (value == null || value.trim().length < 3) {
                                return 'Please enter a valid display name.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _EditSectionCard(
                      icon: Icons.call_outlined,
                      title: 'Contact Information',
                      child: Column(
                        children: [
                          _LabeledField(
                            label: 'Phone Number',
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().length < 8) {
                                return 'Please enter a valid phone number.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _RegionDropdownField(
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
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.homeChrome,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSaveTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
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
                            color: Colors.white,
                          ),
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

class _EditSectionCard extends StatelessWidget {
  const _EditSectionCard({
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
              Icon(icon, size: 20, color: AppColors.authButtonEnd),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

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
                color: AppColors.authButtonEnd,
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

class _RegionDropdownField extends StatelessWidget {
  const _RegionDropdownField({
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
                color: AppColors.authButtonEnd,
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

class _MissingRegionWarning extends StatelessWidget {
  const _MissingRegionWarning({required this.message});

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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
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

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _FavoriteDishTile extends StatelessWidget {
  const _FavoriteDishTile({
    required this.dish,
    required this.onTap,
    required this.onAddTap,
  });

  final DishModel dish;
  final VoidCallback onTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.homeMintSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.homeCardBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: dish.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.homeDivider,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.homeDivider,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dish.cookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dish.price.toStringAsFixed(0)} SR',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onAddTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.homeChrome,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChoiceTile extends StatelessWidget {
  const _AvatarChoiceTile({
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
              ? AppColors.homeChrome.withValues(alpha: 0.12)
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
                width: 92,
                height: 92,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imagePath,
    required this.fallbackAssetPath,
    required this.size,
    required this.badgeColor,
    required this.onBadgeTap,
    required this.badgeIcon,
  });

  final String imagePath;
  final String fallbackAssetPath;
  final double size;
  final Color badgeColor;
  final VoidCallback onBadgeTap;
  final IconData badgeIcon;

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
                child: Icon(badgeIcon, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath, fit: BoxFit.cover);
    }

    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppColors.homeDivider),
        errorWidget: (context, url, error) => Image.asset(
          fallbackAssetPath,
          fit: BoxFit.cover,
        ),
      );
    }

    final localImage = File(imagePath);
    if (localImage.existsSync()) {
      return Image.file(
        localImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(fallbackAssetPath, fit: BoxFit.cover);
        },
      );
    }

    return Image.asset(fallbackAssetPath, fit: BoxFit.cover);
  }
}

class _GalleryImageTile extends StatelessWidget {
  const _GalleryImageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.homeMintSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.homeCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.authButtonEnd,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose from gallery',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use any photo from your phone.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
