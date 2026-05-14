import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/screens/auth/role_selection_screen.dart';
import 'package:naham_app/screens/auth/widgets/auth_error_message.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialData});

  final PendingRegistration? initialData;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _rememberMe = true;
  String _selectedCountryCode = '+966';
  String? _initialDataSignature;

  static const List<_CountryDialCode> _countryCodes = [
    _CountryDialCode(name: 'Saudi Arabia', dialCode: '+966'),
    _CountryDialCode(name: 'Yemen', dialCode: '+967'),
    _CountryDialCode(name: 'United Arab Emirates', dialCode: '+971'),
    _CountryDialCode(name: 'Kuwait', dialCode: '+965'),
    _CountryDialCode(name: 'Qatar', dialCode: '+974'),
    _CountryDialCode(name: 'Bahrain', dialCode: '+973'),
    _CountryDialCode(name: 'Oman', dialCode: '+968'),
    _CountryDialCode(name: 'Egypt', dialCode: '+20'),
    _CountryDialCode(name: 'Jordan', dialCode: '+962'),
    _CountryDialCode(name: 'Iraq', dialCode: '+964'),
    _CountryDialCode(name: 'United States', dialCode: '+1'),
    _CountryDialCode(name: 'United Kingdom', dialCode: '+44'),
  ];

  @override
  void initState() {
    super.initState();
    _applyInitialData();
  }

  @override
  void didUpdateWidget(covariant RegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyInitialData();
  }

  void _applyInitialData() {
    final initialData = widget.initialData;
    final signature = initialData == null
        ? null
        : [
            initialData.name,
            initialData.phone,
            initialData.countryCode,
            initialData.email,
            initialData.password,
          ].join('|');

    if (signature == _initialDataSignature) {
      return;
    }
    _initialDataSignature = signature;

    if (initialData == null) {
      return;
    }

    _nameCtrl.text = initialData.name;
    _phoneCtrl.text = initialData.phone;
    _emailCtrl.text = initialData.email;
    _passCtrl.text = initialData.password;
    _selectedCountryCode = _resolveCountryCode(initialData.countryCode);
  }

  String _resolveCountryCode(String value) {
    final normalized = value.trim();
    if (_countryCodes.any((item) => item.dialCode == normalized)) {
      return normalized;
    }
    return '+966';
  }

  Future<void> _continueToRoleSelection() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();

    context.push(
      AppRoutes.roleSelection,
      extra: PendingRegistration.email(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        countryCode: _selectedCountryCode,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      ),
    );
  }

  Future<void> _continueWithGoogle() async {
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final draft = await auth.pickGoogleAccountDraft();

    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _nameCtrl.text = draft.name;
      _emailCtrl.text = draft.email;
      _phoneCtrl.text = draft.phone;
      _passCtrl.clear();
      _selectedCountryCode = _resolveCountryCode(draft.countryCode);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final topSectionHeight = math
                .min(constraints.maxHeight * 0.485, 398.0)
                .clamp(338.0, 398.0)
                .toDouble();
            final cardWidth =
                math.min(width - 58, 320.0).clamp(270.0, 320.0).toDouble();
            final cardTop = topSectionHeight * 0.82;
            final stackHeight =
                math.max(constraints.maxHeight, cardTop + 508.0);
            final logoSize =
                math.min(width * 0.22, 92.0).clamp(76.0, 92.0).toDouble();
            final titleWidth = math.min(width * 0.74, 290.0);
            final titleFontSize =
                math.min(width * 0.088, 28.0).clamp(24.0, 28.0).toDouble();
            final subtitleFontSize =
                math.min(width * 0.039, 14.0).clamp(12.0, 14.0).toDouble();
            final topInset = MediaQuery.of(context).padding.top;
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboardInset + 24),
              child: SizedBox(
                height: stackHeight,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          height: topSectionHeight,
                          width: double.infinity,
                          color: AppColors.brandSage,
                        ),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: topInset + 38,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/naham_logo.png',
                            width: logoSize,
                            height: logoSize,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: titleWidth,
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Create your',
                                    maxLines: 1,
                                    style: GoogleFonts.poppins(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Account',
                                    maxLines: 1,
                                    style: GoogleFonts.poppins(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: math.min(width * 0.86, 320.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Enter your details to sign up',
                                maxLines: 1,
                                style: GoogleFonts.poppins(
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.84),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: cardTop,
                      left: (width - cardWidth) / 2,
                      child: SizedBox(
                        width: cardWidth,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.045),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SocialButton(
                                onTap:
                                    auth.isLoading ? null : _continueWithGoogle,
                                isLoading: auth.isLoading,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFFF0F1F5),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'Or',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFB3B7C2),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFFF0F1F5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _AuthField(
                                      controller: _nameCtrl,
                                      hintText: 'John Smith',
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().length < 3) {
                                          return 'Please enter your full name.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _PhoneAuthField(
                                      controller: _phoneCtrl,
                                      selectedCountryCode: _selectedCountryCode,
                                      countryCodes: _countryCodes,
                                      onCountryChanged: (value) {
                                        setState(
                                            () => _selectedCountryCode = value);
                                      },
                                      validator: (value) {
                                        final digits = value?.replaceAll(
                                                RegExp(r'\D'), '') ??
                                            '';
                                        if (digits.length < 7) {
                                          return 'Please enter a valid phone number.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _AuthField(
                                      controller: _emailCtrl,
                                      hintText: 'Loisbecket@gmail.com',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email.';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Please enter a valid email.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _AuthField(
                                      controller: _passCtrl,
                                      hintText: '********',
                                      obscureText: _obscurePass,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password.';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters.';
                                        }
                                        return null;
                                      },
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _obscurePass = !_obscurePass;
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: const Color(0xFFC0C4CF),
                                          size: 17,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            visualDensity: const VisualDensity(
                                              horizontal: -4,
                                              vertical: -4,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFC7CBD6),
                                            ),
                                            activeColor:
                                                AppColors.authButtonEnd,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Remember me',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            color: const Color(0xFF8F95A3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (auth.errorMessage != null) ...[
                                      const SizedBox(height: 12),
                                      AuthErrorMessage(
                                        message: auth.errorMessage!,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 50,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.authButtonStart,
                                              AppColors.authButtonEnd,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: auth.isLoading
                                              ? null
                                              : _continueToRoleSelection,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: EdgeInsets.zero,
                                            minimumSize:
                                                const Size.fromHeight(50),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: auth.isLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'Sign Up',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.0,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Have an account? ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            color: const Color(0xFF8F95A3),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              context.go(AppRoutes.login),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Log In',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.authButtonEnd,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onTap,
    required this.isLoading,
  });

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.authButtonEnd,
                ),
              )
            else ...[
              const _GoogleLogo(size: 18),
              const SizedBox(width: 11),
              Text(
                'Continue with Google',
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF30323A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textDirection: TextDirection.ltr,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF2E3138),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFFB5BAC7),
          ),
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 34,
          ),
          filled: false,
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _PhoneAuthField extends StatelessWidget {
  const _PhoneAuthField({
    required this.controller,
    required this.selectedCountryCode,
    required this.countryCodes,
    required this.onCountryChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String selectedCountryCode;
  final List<_CountryDialCode> countryCodes;
  final ValueChanged<String> onCountryChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final selectedCountry = countryCodes.firstWhere(
      (item) => item.dialCode == selectedCountryCode,
      orElse: () => countryCodes.first,
    );

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCountry.dialCode,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF9095A3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                borderRadius: BorderRadius.circular(12),
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E3138),
                ),
                items: countryCodes
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.dialCode,
                        child: Text(item.dialCode),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onCountryChanged(value);
                  }
                },
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: const Color(0xFFE6E8F0),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2E3138),
              ),
              decoration: InputDecoration(
                hintText: '05********',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFB5BAC7),
                ),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryDialCode {
  const _CountryDialCode({
    required this.name,
    required this.dialCode,
  });

  final String name;
  final String dialCode;
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.20;
    final radius = (size.shortestSide - strokeWidth) / 2.15;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _degreesToRadians(118),
      _degreesToRadians(118),
      false,
      arcPaint(const Color(0xFF4285F4)),
    );
    canvas.drawArc(
      rect,
      _degreesToRadians(238),
      _degreesToRadians(92),
      false,
      arcPaint(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      rect,
      _degreesToRadians(332),
      _degreesToRadians(56),
      false,
      arcPaint(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      _degreesToRadians(34),
      _degreesToRadians(82),
      false,
      arcPaint(const Color(0xFF34A853)),
    );

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.5),
      Offset(size.width * 0.84, size.height * 0.5),
      barPaint,
    );
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
