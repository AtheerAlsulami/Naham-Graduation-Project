import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/screens/auth/widgets/auth_error_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _rememberMe = true;

  Future<void> _handleAuthSuccess(AuthProvider auth) async {
    switch (auth.currentUser?.role) {
      case AppConstants.roleCustomer:
        context.go(AppRoutes.customerHome);
        break;
      case AppConstants.roleCook:
        final status = auth.currentUser?.cookStatus;
        if (status == AppConstants.cookApproved) {
          context.go(AppRoutes.cookDashboard);
        } else if (status == AppConstants.cookPendingVerification) {
          context.go(AppRoutes.cookWaitingApproval);
        } else {
          context.go(AppRoutes.cookVerificationUpload);
        }
        break;
      case AppConstants.roleAdmin:
        context.go(AppRoutes.adminDashboard);
        break;
      default:
        context.go(AppRoutes.login);
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );

    if (!mounted || !success) return;
    await _handleAuthSuccess(auth);
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();

    if (!mounted || !success) return;
    await _handleAuthSuccess(auth);
  }

  Future<void> _sendPasswordResetEmail() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter your email first to receive the reset link.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;

    if (success) {
      _showMessage('Password reset email sent. Check your inbox.');
      auth.clearError();
    }
  }

  // ignore: unused_element
  void _fillTemporaryAdminCredentials() {
    setState(() {
      _emailCtrl.text = AppConstants.tempAdminEmail;
      _passCtrl.text = AppConstants.tempAdminPassword;
      _obscurePass = false;
    });
    _showMessage('Temporary admin credentials filled.');
  }

  void _showMessage(String message) {
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
  void dispose() {
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
                math.max(constraints.maxHeight, cardTop + 390.0);
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
                                    'Sign in to your',
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
                                'Enter your email and password to log in',
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
                                    auth.isLoading ? null : _signInWithGoogle,
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
                                        horizontal: 12),
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
                                        const Spacer(),
                                        TextButton(
                                          onPressed: auth.isLoading
                                              ? null
                                              : _sendPasswordResetEmail,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Forgot Password ?',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.authButtonEnd,
                                            ),
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
                                          onPressed:
                                              auth.isLoading ? null : _login,
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
                                                  'Log In',
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
                                          "Don't have an account? ",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            color: const Color(0xFF8F95A3),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              context.go(AppRoutes.register),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Sign Up',
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
