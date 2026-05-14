import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/screens/cook/cook_ai_pricing_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class CookDishFormPayload {
  const CookDishFormPayload.add()
      : isEdit = false,
        dishData = null;

  const CookDishFormPayload.edit({required this.dishData}) : isEdit = true;

  final bool isEdit;
  final Map<String, dynamic>? dishData;
}

class CookDishFormScreen extends StatefulWidget {
  const CookDishFormScreen({
    super.key,
    this.payload = const CookDishFormPayload.add(),
  });

  final CookDishFormPayload payload;

  @override
  State<CookDishFormScreen> createState() => _CookDishFormScreenState();
}

class _CookDishFormScreenState extends State<CookDishFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepMinutesController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedCategoryId = _dishCategories.first.id;
  final List<String> _photoUrls = <String>[];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  bool get _isEdit => widget.payload.isEdit;

  @override
  void initState() {
    super.initState();
    _seedInitialData();
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _descriptionController.dispose();
    _prepMinutesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _seedInitialData() {
    final data = widget.payload.dishData;
    if (data == null) {
      _prepMinutesController.text = '25';
      _priceController.text = '25';
      return;
    }

    _dishNameController.text = (data['name'] ?? '').toString();
    _descriptionController.text = (data['description'] ?? '').toString();
    _prepMinutesController.text = (data['preparationTimeMin'] ?? 25).toString();

    final price = data['price'];
    if (price is num) {
      _priceController.text =
          price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
    } else {
      _priceController.text = price?.toString() ?? '25';
    }

    final category = (data['categoryId'] ?? '').toString();
    final exists = _dishCategories.any((item) => item.id == category);
    if (exists) {
      _selectedCategoryId = category;
    }

    final photos = data['photos'];
    if (photos is List) {
      _photoUrls
        ..clear()
        ..addAll(
          photos
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .take(3),
        );
    }
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
              padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.homeChrome,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Dish' : 'Add new dish',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhotoUploadCard(
                        photoUrls: _photoUrls,
                        onTap: _showPhotoPickerSheet,
                        onRemoveAt: _removePhotoAt,
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(text: 'Dish Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dishNameController,
                        textInputAction: TextInputAction.next,
                        style: _fieldTextStyle,
                        decoration: _fieldDecoration('Dish Name'),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Dish name is required';
                          if (trimmed.length < 3) {
                            return 'Dish name should be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      _HelperText(
                        text: 'Example: Margog what makes your dish special.',
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(text: 'Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: _fieldTextStyle,
                        decoration: _fieldDecoration('Description'),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Description is required';
                          if (trimmed.length < 20) {
                            return 'Description should be at least 20 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      _HelperText(
                          text: 'Explain what makes your dish special.'),
                      const SizedBox(height: 12),
                      _FieldLabel(text: 'Category'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFADB2BC),
                        ),
                        style: _fieldTextStyle,
                        decoration: _fieldDecoration('Category'),
                        items: _dishCategories
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedCategoryId = value);
                        },
                      ),
                      const SizedBox(height: 6),
                      _HelperText(text: 'Choose the closest category.'),
                      const SizedBox(height: 12),
                      _FieldLabel(text: 'Preparation Time (Min)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _prepMinutesController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        style: _fieldTextStyle,
                        decoration: _fieldDecoration(
                          '0',
                          prefixIcon: const Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: Color(0xFFA7ACB6),
                          ),
                        ),
                        validator: (value) {
                          final minutes = int.tryParse((value ?? '').trim());
                          if (minutes == null) return 'Enter valid minutes';
                          if (minutes < 5 || minutes > 240) {
                            return 'Minutes must be between 5 and 240';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      _HelperText(
                          text: 'How long does it take to prepare this dish?'),
                      const SizedBox(height: 12),
                      _FieldLabel(text: 'Price'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        style: _fieldTextStyle,
                        decoration: _fieldDecoration('0'),
                        validator: (value) {
                          final normalized =
                              (value ?? '').trim().replaceAll(',', '.');
                          final parsed = double.tryParse(normalized);
                          if (parsed == null) return 'Enter valid price';
                          if (parsed <= 0 || parsed > 5000) {
                            return 'Price must be between 1 and 5000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _startAiPricing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A4DFF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Start AI Pricing',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B7AD1),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEdit ? 'Edit' : 'Add Dish',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoPickerSheet() async {
    if (_photoUrls.length >= 3) {
      _showSnack('You can upload only 3 photos');
      return;
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // Full quality
    );

    if (pickedFile != null) {
      _addPhoto(pickedFile.path);
    }
  }

  void _addPhoto(String url) {
    if (_photoUrls.length >= 3) {
      _showSnack('You can upload only 3 photos');
      return;
    }
    if (_photoUrls.contains(url)) {
      _showSnack('This photo is already selected');
      return;
    }
    setState(() => _photoUrls.add(url));
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _photoUrls.length) return;
    setState(() => _photoUrls.removeAt(index));
  }

  Future<void> _startAiPricing() async {
    final prep = int.tryParse(_prepMinutesController.text.trim()) ?? 0;
    if (prep <= 0) {
      _showSnack('Enter preparation time first');
      return;
    }

    final currentPrice = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    final result = await context.push<Object?>(
      AppRoutes.cookAiPricing,
      extra: CookAiPricingPayload(
        categoryId: _selectedCategoryId,
        preparationMinutes: prep,
        currentPrice: currentPrice,
      ),
    );

    if (!mounted || result is! Map) {
      return;
    }

    final suggestedPrice = result['price'];
    if (suggestedPrice is! num) {
      return;
    }

    final priceValue = suggestedPrice.toDouble();
    final formatted = priceValue % 1 == 0
        ? priceValue.toInt().toString()
        : priceValue.toStringAsFixed(2);

    setState(() => _priceController.text = formatted);
    _showSnack('AI price applied: $formatted SAR');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_photoUrls.isEmpty) {
      _showSnack('Please upload at least one photo');
      return;
    }

    setState(() => _isSaving = true);

    final priceText = _priceController.text.trim().replaceAll(',', '.');
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      _showSnack('You must be logged in to add a dish');
      setState(() => _isSaving = false);
      return;
    }

    final dishId = widget.payload.dishData?['id'] ?? const Uuid().v4();
    final isEdit = widget.payload.isEdit;

    final newDish = DishModel(
      id: dishId,
      cookId: currentUser.id,
      cookName: currentUser.name,
      name: _dishNameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(priceText),
      imageUrl: _photoUrls.isNotEmpty && _photoUrls.first.startsWith('http')
          ? _photoUrls.first
          : '',
      categoryId: _selectedCategoryId,
      preparationTimeMin: int.parse(_prepMinutesController.text.trim()),
      preparationTimeMax: int.parse(_prepMinutesController.text.trim()) + 15,
      createdAt: isEdit && widget.payload.dishData?['createdAt'] != null
          ? DateTime.tryParse(widget.payload.dishData!['createdAt']) ??
              DateTime.now()
          : DateTime.now(),
    );

    // Filter out only the local files for uploading
    final localImageFiles = _photoUrls
        .where((path) => !path.startsWith('http'))
        .map((path) => File(path))
        .toList();

    final dishProvider = context.read<DishProvider>();
    final errorMessage = await dishProvider.addDish(newDish, localImageFiles);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (errorMessage == null) {
      _showSnack(
          isEdit ? 'Dish updated successfully' : 'Dish added successfully');
      context.pop(<String, dynamic>{
        'action': 'save',
        'dish': newDish.toMap(),
      });
    } else {
      _showSnack('Failed to save dish: $errorMessage');
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

class _PhotoUploadCard extends StatelessWidget {
  const _PhotoUploadCard({
    required this.photoUrls,
    required this.onTap,
    required this.onRemoveAt,
  });

  final List<String> photoUrls;
  final VoidCallback onTap;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E3E9)),
        ),
        child: photoUrls.isEmpty
            ? Container(
                height: 126,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9DDE5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFE9FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_rounded,
                        size: 17,
                        color: Color(0xFF8665C8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Upload Photos',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4D6B58),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Up to 3 images',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFA3A9B5),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Photos (${photoUrls.length}/3)',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to add more',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(photoUrls.length, (index) {
                      final url = photoUrls[index];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: url.startsWith('http')
                                ? Image.network(
                                    url,
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 84,
                                        height: 84,
                                        color: const Color(0xFFE7EAF0),
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Color(0xFF9DA4B2),
                                        ),
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(url),
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 84,
                                        height: 84,
                                        color: const Color(0xFFE7EAF0),
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Color(0xFF9DA4B2),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () => onRemoveAt(index),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1D1E22),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF39584A),
      ),
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.5,
        color: const Color(0xFFA5ABB5),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  String hintText, {
  Widget? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: GoogleFonts.poppins(
      color: const Color(0xFFB8BEC9),
      fontSize: 14,
    ),
    filled: true,
    fillColor: const Color(0xFFF0F2F6),
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      borderSide: const BorderSide(color: AppColors.homeChrome, width: 1.1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error, width: 1.1),
    ),
  );
}

final TextStyle _fieldTextStyle = GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: AppColors.textPrimary,
);

class _DishCategoryItem {
  const _DishCategoryItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

const List<_DishCategoryItem> _dishCategories = [
  _DishCategoryItem(id: 'northern', label: 'Northern'),
  _DishCategoryItem(id: 'eastern', label: 'Eastern'),
  _DishCategoryItem(id: 'southern', label: 'Southern'),
  _DishCategoryItem(id: 'najdi', label: 'Najdi'),
  _DishCategoryItem(id: 'western', label: 'Western'),
  _DishCategoryItem(id: 'sweets', label: 'Sweets'),
  _DishCategoryItem(id: 'baked', label: 'Baked'),
];
