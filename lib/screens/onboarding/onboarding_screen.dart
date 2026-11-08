import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../splash/splash_screen.dart';
import 'widgets/onboarding_action_footer.dart';
import 'widgets/onboarding_backdrop_painter.dart';
import 'widgets/onboarding_top_bar.dart';
import 'widgets/onboarding_visual_card.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final String image;
  final String tag;
  final String highlight;
  final IconData icon;
  final Alignment alignment;

  const OnboardingSlide(
    this.title,
    this.description,
    this.image, {
    this.tag = 'مركز الأمين',
    this.highlight = 'منهج تدريبي متكامل',
    this.icon = PhosphorIconsRegular.graduationCap,
    this.alignment = Alignment.center,
  });
}

const onboardingSlides = [
  OnboardingSlide(
    'التعلّم يبدأ بخطوة',
    'مسارات تدريبية متدرجة في التخاطب وتعديل السلوك، مصممة للأخصائيين وأولياء الأمور بمنهج علمي واضح.',
    'assets/onboarding/onboarding-01-learning.jpeg',
    tag: 'مسارات منهجية',
    highlight: 'مستويات مرتبة من التأسيس للاحتراف',
    icon: PhosphorIconsRegular.graduationCap,
    alignment: Alignment.center,
  ),
  OnboardingSlide(
    'تأسيس علمي بلغة واضحة',
    'تعرّف على أسس النطق واللغة ومهارات التواصل عبر محاضرات مرتبة تسهّل استيعاب المفاهيم الإكلينيكية.',
    'assets/onboarding/onboarding-02-foundations.jpeg',
    tag: 'تأهيل متخصص',
    highlight: 'شرح مبسط للحالات التشخيصية الواقعية',
    icon: PhosphorIconsRegular.waveform,
    alignment: Alignment(0, -0.25),
  ),
  OnboardingSlide(
    'من المعرفة إلى التطبيق',
    'اربط الجانب النظري بتدريبات الجلسات الواقعية وتابع تقدمك في كل مستوى مع تكليفات تطبيقية عملية.',
    'assets/onboarding/onboarding-03-practice.jpeg',
    tag: 'تطبيق عملي',
    highlight: 'تكليفات وتقييم مباشر مع تحليل لأدائك',
    icon: PhosphorIconsRegular.clipboardText,
    alignment: Alignment(0, -0.2),
  ),
  OnboardingSlide(
    'ابدأ رحلتك مع الأمين',
    'انضم إلى مجتمع المتدربين في مركز الأمين للتخاطب وتنمية المهارات، وتابع دوراتك في أي وقت.',
    'assets/onboarding/onboarding-04-community.jpeg',
    tag: 'مجتمع الأمين',
    highlight: 'وصول مرن وآمن على الهاتف والكمبيوتر',
    icon: PhosphorIconsRegular.usersThree,
    alignment: Alignment.center,
  ),
];

class OnboardingGate extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelectRegister;
  final VoidCallback? onSelectLogin;

  const OnboardingGate({
    super.key,
    required this.child,
    this.onSelectRegister,
    this.onSelectLogin,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _complete;
  int _initialPage = 0;
  Future<void> _saveTail = Future.value();
  String? _error;
  final _prefs = SharedPreferencesAsync();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final done = await _prefs.getInt('onboarding.version') == 1;
      _initialPage = (await _prefs.getInt('onboarding.page') ?? 0).clamp(
        0,
        onboardingSlides.length - 1,
      );
      if (mounted) {
        setState(() {
          _complete = done;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل تفضيلات البداية. حاول مرة أخرى.');
      }
    }
  }

  Future<void> _markCompleted() async {
    await _saveTail;
    await _prefs.setInt('onboarding.version', 1);
    if (mounted) {
      setState(() => _complete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_complete == null) {
      return const SplashScreen();
    }

    if (_complete!) return widget.child;

    return OnboardingScreen(
      initialPage: _initialPage,
      onPageChanged: (page) {
        _saveTail = _saveTail
            .then((_) => _prefs.setInt('onboarding.page', page))
            .catchError((Object _) {});
      },
      onComplete: () async {
        await _markCompleted();
        widget.onSelectRegister?.call();
      },
      onSignInTap: () async {
        await _markCompleted();
        widget.onSelectLogin?.call();
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;
  final Future<void> Function()? onSignInTap;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.onSignInTap,
    this.initialPage = 0,
    this.onPageChanged,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pages;
  late int _index;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialPage.clamp(0, onboardingSlides.length - 1);
    _pages = PageController(initialPage: _index);
  }

  double get _currentPageValue {
    if (_pages.hasClients && _pages.position.haveDimensions) {
      return _pages.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  Future<void> _runFinish(Future<void> Function() callback) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await callback();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ اختيارك. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isWide = size.width >= 760 && size.height >= 460;

    return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: AnimatedBuilder(
          animation: _pages,
          builder: (context, child) {
            return CustomPaint(
              painter: OnboardingBackdropPainter(
                pageProgress: _currentPageValue,
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1020 : 580),
                child: Column(
                  children: [
                    OnboardingTopBar(
                      currentStep: _index + 1,
                      totalSteps: onboardingSlides.length,
                      onSkip: _saving
                          ? null
                          : () => _runFinish(
                                widget.onSignInTap ?? widget.onComplete,
                              ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: onboardingSlides.length,
                        onPageChanged: (value) {
                          setState(() => _index = value);
                          widget.onPageChanged?.call(value);
                        },
                        itemBuilder: (context, i) {
                          final slide = onboardingSlides[i];
                          return AnimatedBuilder(
                            animation: _pages,
                            builder: (context, _) {
                              final delta = (_currentPageValue - i).clamp(
                                -1.0,
                                1.0,
                              );
                              final scale = 1.0 - (delta.abs() * 0.055);
                              final opacity = 1.0 - (delta.abs() * 0.30);
                              final parallax = delta * 26.0;
                              final textOffset = delta.abs() * 12.0;

                              return Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: scale,
                                  child: _buildSlideLayout(
                                    context: context,
                                    slide: slide,
                                    slideIndex: i,
                                    isWide: isWide,
                                    textScale: textScale,
                                    parallax: parallax,
                                    textOffset: textOffset,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    OnboardingActionFooter(
                      currentIndex: _index,
                      totalSteps: onboardingSlides.length,
                      isLastSlide: _index == onboardingSlides.length - 1,
                      isSaving: _saving,
                      onPreviousPressed: _index > 0
                          ? () {
                              _pages.previousPage(
                                duration: const Duration(milliseconds: 360),
                                curve: Curves.easeOutQuart,
                              );
                            }
                          : null,
                      onPrimaryPressed: () {
                        if (_index == onboardingSlides.length - 1) {
                          _runFinish(widget.onComplete);
                        } else {
                          _pages.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutQuart,
                          );
                        }
                      },
                      onSignInPressed: () => _runFinish(
                        widget.onSignInTap ?? widget.onComplete,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildSlideLayout({
    required BuildContext context,
    required OnboardingSlide slide,
    required int slideIndex,
    required bool isWide,
    required double textScale,
    required double parallax,
    required double textOffset,
  }) {
    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: OnboardingVisualCard(
                imageAsset: slide.image,
                semanticLabel: slide.title,
                categoryTag: slide.tag,
                tagIcon: slide.icon,
                stepNumber: slideIndex + 1,
                totalSteps: onboardingSlides.length,
                imageAlignment: slide.alignment,
                parallaxOffset: parallax,
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Transform.translate(
                  offset: Offset(0, textOffset),
                  child: _SlideTextContent(
                    slide: slide,
                    alignStart: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useScrollFallback =
            constraints.maxHeight < 360 || textScale > 1.32;

        if (useScrollFallback) {
          final compactVisualH = (constraints.maxHeight * 0.42).clamp(
            110.0,
            210.0,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                OnboardingVisualCard(
                  imageAsset: slide.image,
                  semanticLabel: slide.title,
                  categoryTag: slide.tag,
                  tagIcon: slide.icon,
                  stepNumber: slideIndex + 1,
                  totalSteps: onboardingSlides.length,
                  imageAlignment: slide.alignment,
                  parallaxOffset: parallax,
                  fixedHeight: compactVisualH,
                ),
                const SizedBox(height: 14),
                _SlideTextContent(slide: slide, alignStart: false),
              ],
            ),
          );
        }

        // توزيع متوازن بدون أي فراغ ميت على شاشات الهواتف الحديثة
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              Expanded(
                flex: 62,
                child: OnboardingVisualCard(
                  imageAsset: slide.image,
                  semanticLabel: slide.title,
                  categoryTag: slide.tag,
                  tagIcon: slide.icon,
                  stepNumber: slideIndex + 1,
                  totalSteps: onboardingSlides.length,
                  imageAlignment: slide.alignment,
                  parallaxOffset: parallax,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 38,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Transform.translate(
                      offset: Offset(0, textOffset),
                      child: _SlideTextContent(
                        slide: slide,
                        alignStart: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlideTextContent extends StatelessWidget {
  final OnboardingSlide slide;
  final bool alignStart;

  const _SlideTextContent({
    required this.slide,
    required this.alignStart,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final align = alignStart ? TextAlign.start : TextAlign.center;

    return Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slide.highlight,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          slide.title,
          textAlign: align,
          style: TextStyle(
            fontFamily: 'Baloo Bhaijaan 2',
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w700,
            height: 1.28,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            slide.description,
            textAlign: align,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: compact ? 14 : 15,
              height: 1.65,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
