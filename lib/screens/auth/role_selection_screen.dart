import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/screens/auth/widgets/auth_error_message.dart';
import 'package:provider/provider.dart';

class PendingRegistration {
  const PendingRegistration.email({
    required this.name,
    required this.phone,
    required this.countryCode,
    required this.email,
    required this.password,
  });

  final String name;
  final String phone;
  final String countryCode;
  final String email;
  final String password;

  String get fullPhone {
    final normalizedCode = countryCode.trim();
    final localDigits = phone.replaceAll(RegExp(r'\s+'), '');
    final normalizedLocal =
        localDigits.startsWith('0') ? localDigits.substring(1) : localDigits;
    return '$normalizedCode$normalizedLocal';
  }
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.registration});

  final PendingRegistration? registration;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  PendingRegistration? _registration;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _registration = widget.registration;
  }

  @override
  void didUpdateWidget(covariant RoleSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.registration != null) {
      _registration = widget.registration;
    }
  }

  Future<void> _chooseRole(String role) async {
    final registration = _registration;
    if (registration == null) {
      context.go(AppRoutes.register);
      return;
    }

    setState(() => _selectedRole = role);
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.register(
      name: registration.name,
      email: registration.email,
      password: registration.password,
      phone: registration.fullPhone,
      role: role,
    );

    if (!mounted) return;
    setState(() => _selectedRole = null);
    if (!success) return;
    _goToRoleHome(auth.currentUser?.role ?? role);
  }

  void _goToRoleHome(String role) {
    switch (role) {
      case AppConstants.roleCustomer:
        context.go(AppRoutes.customerHome);
        break;
      case AppConstants.roleCook:
        final user = context.read<AuthProvider>().currentUser;
        final status = user?.cookStatus;
        if (status == AppConstants.cookApproved) {
          context.go(AppRoutes.cookDashboard);
        } else if (status == AppConstants.cookPendingVerification) {
          context.go(AppRoutes.cookWaitingApproval);
        } else {
          context.go(AppRoutes.cookVerificationUpload);
        }
        break;
      default:
        context.go(AppRoutes.customerHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.isLoading;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFA489DD),
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 42),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'who are you?',
                              maxLines: 1,
                              style: GoogleFonts.caveat(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4.2,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 45),
                          _RoleButton(
                            label: "I'm a Customer",
                            isLoading: isLoading &&
                                _selectedRole == AppConstants.roleCustomer,
                            isDisabled: isLoading,
                            onTap: () => _chooseRole(AppConstants.roleCustomer),
                          ),
                          const SizedBox(height: 26),
                          _RoleButton(
                            label: "I'm a Cook",
                            isLoading: isLoading &&
                                _selectedRole == AppConstants.roleCook,
                            isDisabled: isLoading,
                            onTap: () => _chooseRole(AppConstants.roleCook),
                          ),
                          if (auth.errorMessage != null) ...[
                            const SizedBox(height: 26),
                            SizedBox(
                              width: 280,
                              child: AuthErrorMessage(
                                message: auth.errorMessage!,
                                onDarkBackground: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              child: Center(
                child: Container(
                  width: 96,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      height: 48,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF9EA),
          disabledBackgroundColor:
              const Color(0xFFFFF9EA).withValues(alpha: 0.7),
          foregroundColor: AppColors.primaryDark,
          disabledForegroundColor:
              AppColors.primaryDark.withValues(alpha: 0.55),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryDark,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: AppColors.primaryDark,
                    height: 1.0,
                  ),
                ),
              ),
      ),
    );
  }
}
