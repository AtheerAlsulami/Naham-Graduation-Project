import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/delivery_address_model.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({
    super.key,
    required this.initialAddress,
  });

  final DeliveryAddressModel initialAddress;

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _postcodeController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.initialAddress.address,
    );
    _cityController = TextEditingController(text: widget.initialAddress.city);
    _postcodeController = TextEditingController(
      text: widget.initialAddress.postcode,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _ShippingHeader(onBackTap: () => _goBack(context)),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 18, 18, 24),
                children: [
                  Text('Country', style: _fieldLabelStyle),
                  const SizedBox(height: 6),
                  _CountrySelector(country: widget.initialAddress.country),
                  const SizedBox(height: 16),
                  _AddressTextField(
                    label: 'Address',
                    controller: _addressController,
                  ),
                  const SizedBox(height: 14),
                  _AddressTextField(
                    label: 'Town / City',
                    controller: _cityController,
                  ),
                  const SizedBox(height: 14),
                  _AddressTextField(
                    label: 'Postcode',
                    controller: _postcodeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.homeChrome,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final address = DeliveryAddressModel(
      country: widget.initialAddress.country,
      address: _addressController.text.trim().isEmpty
          ? widget.initialAddress.address
          : _addressController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? widget.initialAddress.city
          : _cityController.text.trim(),
      postcode: _postcodeController.text.trim().isEmpty
          ? widget.initialAddress.postcode
          : _postcodeController.text.trim(),
      label: widget.initialAddress.label,
    );
    context.pop(address);
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }
}

class _ShippingHeader extends StatelessWidget {
  const _ShippingHeader({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: topPadding + 82,
      padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 0),
      color: AppColors.homeSoftGreen,
      child: Row(
        children: [
          Tooltip(
            message: 'Back to checkout',
            child: Semantics(
              button: true,
              label: 'Back to checkout',
              child: GestureDetector(
                onTap: onBackTap,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 34,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Shipping Address',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({required this.country});

  final String country;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            country,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.brandSage,
            ),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.brandSage,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _AddressTextField extends StatelessWidget {
  const _AddressTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: 35,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.homeMintSurface,
              border: _addressBorder(BorderSide.none),
              enabledBorder: _addressBorder(BorderSide.none),
              focusedBorder: _addressBorder(
                const BorderSide(color: AppColors.brandSage),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _addressBorder(BorderSide side) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: side,
    );
  }
}

final TextStyle _fieldLabelStyle = GoogleFonts.poppins(
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  color: AppColors.primaryDark,
);
