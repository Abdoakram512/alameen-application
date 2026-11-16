import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_lottie_box.dart';
import '../../logic/auth/admin_auth_cubit.dart';
import '../../logic/auth/admin_auth_state.dart';

class SplashScreen extends StatefulWidget {
  final bool isBootstrapping;

  const SplashScreen({
    super.key,
    this.isBootstrapping = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _minTimer;
  Timer? _maxTimeoutTimer;
  bool _minTimerPassed = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = const AlwaysStoppedAnimation(1.0);
    _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    _controller.forward();

    if (!widget.isBootstrapping) {
      // الحد الأدنى المحسن للعرض (350ms) لتوفير انتقال فوري وسلس دون تأخير اصطناعي
      _minTimer = Timer(const Duration(milliseconds: 350), () {
        _minTimerPassed = true;
        _checkAndNavigate();
      });

      // Hard fallback timeout (5s) in case of offline / slow auth resolution
      _maxTimeoutTimer = Timer(const Duration(seconds: 5), () {
        if (!_hasNavigated) {
          _hasNavigated = true;
          _safeNavigate(AppRoutes.login);
        }
      });
    }
  }

  void _checkAndNavigate([AdminAuthState? explicitState]) {
    if (!mounted || _hasNavigated || !_minTimerPassed) return;

    final authState = explicitState ?? context.read<AdminAuthCubit>().state;

    // Do NOT navigate while auth is still resolving (prevents race condition to login)
    if (authState is AdminAuthInitial || authState is AdminAuthLoading) {
      return;
    }

    _hasNavigated = true;
    _minTimer?.cancel();
    _maxTimeoutTimer?.cancel();

    if (authState is AdminAuthenticated) {
      _safeNavigate(AppRoutes.dashboard);
    } else {
      _safeNavigate(AppRoutes.login);
    }
  }

  void _safeNavigate(String target) {
    if (!mounted) return;
    try {
      context.go(target);
    } catch (_) {
      // Safe fallback when pumped inside an isolated widget test without GoRouter.
    }
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _maxTimeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompactHeight = constraints.maxHeight < 520;
              final logoSize = isCompactHeight ? 96.0 : 136.0;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: logoSize,
                              height: logoSize,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: AppColors.borderHairline,
                                  width: 1.4,
                                ),
                                boxShadow: AppColors.cardShadow,
                              ),
                              child: Image.asset(
                                AppConstants.logoAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: AppColors.primary,
                                      size: 56,
                                    ),
                              ),
                            ),
                            SizedBox(height: isCompactHeight ? 18 : 26),
                            const Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.royalNavy,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              AppConstants.appNameAr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'لوحة الإدارة والمتابعة الأكاديمية',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.royalNavy,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompactHeight ? 18 : 26),
                            const AppLottieBox(
                              assetPath: 'assets/lottie/learning_orbit.json',
                              width: 48,
                              height: 48,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

    if (widget.isBootstrapping) {
      return scaffold;
    }

    return BlocListener<AdminAuthCubit, AdminAuthState>(
      listener: (context, state) {
        _checkAndNavigate(state);
      },
      child: scaffold,
    );
  }
}
