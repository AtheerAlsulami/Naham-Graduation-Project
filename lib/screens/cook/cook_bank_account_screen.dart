import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/payout_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/services/backend/backend_payout_service.dart';
import 'package:provider/provider.dart';

class CookBankAccountScreen extends StatefulWidget {
  const CookBankAccountScreen({super.key});

  @override
  State<CookBankAccountScreen> createState() => _CookBankAccountScreenState();
}

class _CookBankAccountScreenState extends State<CookBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ibanController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _payoutService = BackendPayoutService();

  bool _isEditing = false;
  bool _showIban = false;
  bool _isLoadingPayouts = false;
  List<PayoutModel> _payouts = const [];

  @override
  void initState() {
    super.initState();
    _ibanController.text = 'SA44 0000 0000 0000 1234';
    _bankNameController.text = 'Al Rajhi Bank';
    _accountHolderController.text = 'Sarah Al-Zahrani';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayouts());
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadPayouts() async {
    final cookId = context.read<AuthProvider>().currentUser?.id ?? '';
    if (cookId.isEmpty) return;
    setState(() => _isLoadingPayouts = true);
    try {
      final payouts = await _payoutService.listPayouts(cookId: cookId);
      if (!mounted) return;
      setState(() => _payouts = payouts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _payouts = const []);
    } finally {
      if (mounted) setState(() => _isLoadingPayouts = false);
    }
  }

  double get _pendingPayoutTotal {
    return _payouts
        .where((payout) => payout.isPending)
        .fold<double>(0, (sum, payout) => sum + payout.amount);
  }

  DateTime? get _nextPayoutDate {
    final pending = _payouts.where((payout) => payout.isPending).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(
          b.createdAt ?? DateTime(0),
        ));
    return pending.first.createdAt?.add(const Duration(days: 7));
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
                      'Bank Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerifiedCard(),
                      const SizedBox(height: 14),
                      _buildBankDetailsCard(),
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

  Widget _buildVerifiedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F4EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDE3CA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFCFEEDC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: Color(0xFF15A45C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Verified',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E6650),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your bank account is verified and ready to receive payments.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        height: 1.35,
                        color: const Color(0xFF4B7764),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Payout',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF6E7685),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isLoadingPayouts
                      ? 'Loading...'
                      : 'SAR ${_pendingPayoutTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF16A45D),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _nextPayoutDate == null
                      ? 'No pending transfers'
                      : 'Expected: ${_nextPayoutDate!.year}-${_nextPayoutDate!.month.toString().padLeft(2, '0')}-${_nextPayoutDate!.day.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF6E7685),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF8A3DFF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bank Details',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF414854),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _handleEditTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: const Color(0xFF5E6573),
                  side: const BorderSide(color: Color(0xFFE2E5EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Text(
                  _isEditing ? 'Save' : 'Edit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FieldTitle(label: 'IBAN Number'),
          const SizedBox(height: 6),
          _isEditing ? _buildIbanEditor() : _buildIbanViewer(),
          const SizedBox(height: 12),
          _FieldTitle(label: 'Bank Name'),
          const SizedBox(height: 6),
          _isEditing
              ? _EditableField(
                  controller: _bankNameController,
                  hintText: 'Enter bank name',
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Bank name is required';
                    return null;
                  },
                )
              : _ReadOnlyField(
                  value: _bankNameController.text.trim(),
                  prefixIcon: Icons.corporate_fare_rounded,
                ),
          const SizedBox(height: 12),
          _FieldTitle(label: 'Account Holder Name'),
          const SizedBox(height: 6),
          _isEditing
              ? _EditableField(
                  controller: _accountHolderController,
                  hintText: 'Enter account holder name',
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Account holder name is required';
                    if (v.length < 3) return 'Enter full account holder name';
                    return null;
                  },
                )
              : _ReadOnlyField(
                  value: _accountHolderController.text.trim(),
                ),
        ],
      ),
    );
  }

  Widget _buildIbanEditor() {
    return TextFormField(
      controller: _ibanController,
      keyboardType: TextInputType.text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: _bankFieldDecoration(
        hintText: 'SA00 0000 0000 0000 0000',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _showIban = !_showIban),
          icon: Icon(
            _showIban ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF8A909D),
            size: 18,
          ),
        ),
      ),
      obscureText: !_showIban,
      validator: (value) {
        final raw = (value ?? '').replaceAll(' ', '').toUpperCase();
        if (raw.isEmpty) return 'IBAN is required';
        if (raw.length < 14) return 'IBAN looks too short';
        if (!raw.startsWith('SA')) return 'IBAN should start with SA';
        return null;
      },
    );
  }

  Widget _buildIbanViewer() {
    return _ReadOnlyField(
      value: _showIban ? _ibanController.text.trim() : _maskedIban,
      suffix: IconButton(
        onPressed: () => setState(() => _showIban = !_showIban),
        icon: Icon(
          _showIban ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF8A909D),
          size: 18,
        ),
      ),
    );
  }

  String get _maskedIban {
    final raw = _ibanController.text.replaceAll(' ', '');
    if (raw.length <= 8) return raw;
    final head = raw.substring(0, 4);
    final tail = raw.substring(raw.length - 4);
    return '$head **** **** **** $tail';
  }

  void _handleEditTap() {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _isEditing = false);
    _showSnack('Bank details updated successfully');
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

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF47505D),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.value,
    this.prefixIcon,
    this.suffix,
  });

  final String value;
  final IconData? prefixIcon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 16, color: const Color(0xFF8A3DFF)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6A7281),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.hintText,
    required this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: _bankFieldDecoration(hintText: hintText),
      validator: validator,
    );
  }
}

InputDecoration _bankFieldDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: GoogleFonts.poppins(
      fontSize: 14,
      color: const Color(0xFFAAB0BC),
    ),
    filled: true,
    fillColor: const Color(0xFFF1F3F7),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  );
}
