import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Stopwatch _startupStopwatch;

  @override
  void initState() {
    super.initState();
    _startupStopwatch = Stopwatch()..start();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus(notifyLoading: false);
    if (authProvider.currentUser?.role == AppConstants.roleCook) {
      await authProvider.refreshCurrentUser();
    }
    if (!mounted) return;

    final remaining = _minSplashDuration - _startupStopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;

    context.go(_resolveNextRoute(authProvider));
  }

  String _resolveNextRoute(AuthProvider authProvider) {
    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      return AppRoutes.login;
    }

    switch (authProvider.currentUser!.role) {
      case AppConstants.roleCustomer:
        return AppRoutes.customerHome;
      case AppConstants.roleCook:
        final status = authProvider.currentUser?.cookStatus;
        if (status == AppConstants.cookApproved) {
          return AppRoutes.cookDashboard;
        }
        if (status == AppConstants.cookPendingVerification) {
          return AppRoutes.cookWaitingApproval;
        }
        return AppRoutes.cookVerificationUpload;
      case AppConstants.roleAdmin:
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.login;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoSize = math
            .min(constraints.maxWidth * 0.36, 160.0)
            .clamp(110.0, 160.0)
            .toDouble();
        final nameWidth = math
            .min(constraints.maxWidth * 0.66, 260.0)
            .clamp(170.0, 260.0)
            .toDouble();

        return Scaffold(
          backgroundColor: AppColors.brandSage,
          body: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/naham_logo.png',
                      width: logoSize,
                      height: logoSize,
                    ),
                    SizedBox(height: logoSize * 0.18),
                    SizedBox(
                      width: nameWidth,
                      child: Image.asset(
                        'assets/naham_name.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
