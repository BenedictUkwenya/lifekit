import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/screens/signup_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/app_localizations.dart';

class _Slide {
  final String image;
  final String title;
  final String desc;
  final Color tint;
  const _Slide(this.image, this.title, this.desc, this.tint);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<_Slide> _slides(AppLocalizations l10n) => [
        _Slide('assets/images/onboarding1.png', l10n.obTitle1, l10n.obDesc1, AppColors.primary),
        _Slide('assets/images/onboarding2.png', l10n.obTitle2, l10n.obDesc2, const Color(0xFFF59E0B)),
        _Slide('assets/images/onboarding3.png', l10n.obTitle3, l10n.obDesc3, const Color(0xFF3B82F6)),
        _Slide('assets/images/onboarding4.png', l10n.obTitle4, l10n.obDesc4, const Color(0xFF8B5CF6)),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish({bool toLogin = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => toLogin ? const LoginScreen() : const SignupFlowWrapper(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = _slides(l10n);
    final isLast = _currentIndex == slides.length - 1;
    final tint = slides[_currentIndex].tint;

    return Scaffold(
      body: AnimatedContainer(
        duration: Motion.slow,
        curve: Motion.curve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint.withValues(alpha: 0.10), Colors.white, Colors.white],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo_black.png', width: 30, height: 30)
                        .animate()
                        .fadeIn(duration: Motion.medium)
                        .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: Motion.medium,
                      opacity: isLast ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: isLast,
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(
                            l10n.skip,
                            style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Slides (illustration + text move with a parallax) ──
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentIndex = i);
                  },
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, _) {
                      double delta = 0;
                      if (_pageController.hasClients && _pageController.position.haveDimensions) {
                        delta = (_pageController.page ?? 0) - index;
                      }
                      return _SlideView(slide: slides[index], delta: delta.clamp(-1.0, 1.0));
                    },
                  ),
                ),
              ),

              // ── Bottom controls ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (i) {
                        final active = i == _currentIndex;
                        return AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.curve,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 7,
                          width: active ? 28 : 7,
                          decoration: BoxDecoration(
                            color: active ? tint : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Pressable(
                      onTap: () {
                        if (isLast) {
                          _finish();
                        } else {
                          _pageController.nextPage(duration: Motion.slow, curve: Motion.curve);
                        }
                      },
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        curve: Motion.curve,
                        height: 58,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF89273B), Color(0xFFBF3F5E)]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: isLast ? 0.45 : 0.25),
                              blurRadius: isLast ? 22 : 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Row(
                            key: ValueKey(isLast),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLast ? l10n.getStarted : l10n.next,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      child: isLast
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextButton(
                                onPressed: () => _finish(toLogin: true),
                                child: Text(
                                  l10n.obHaveAccount,
                                  style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ).fadeSlideIn()
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slide. [delta] is how far (−1…1) this page is from the centre; the
/// blob, illustration and text move at different speeds for depth.
class _SlideView extends StatelessWidget {
  final _Slide slide;
  final double delta;

  const _SlideView({required this.slide, required this.delta});

  @override
  Widget build(BuildContext context) {
    final fade = (1 - delta.abs()).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final art = (c.maxHeight * 0.58).clamp(180.0, 380.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: art,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(delta * -40, 0),
                      child: Transform.scale(
                        scale: 1 - delta.abs() * 0.15,
                        child: Image.asset('assets/images/background_bg.png', height: art, fit: BoxFit.contain),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(delta * -110, 0),
                      child: Image.asset(slide.image, height: art * 0.8, fit: BoxFit.contain)
                          .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
                          .moveY(begin: -6, end: 6, duration: 2600.ms, curve: Curves.easeInOut),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(delta * -160, 0),
                  child: Text(
                    slide.title,
                    style: GoogleFonts.poppins(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: fade * fade,
                child: Transform.translate(
                  offset: Offset(delta * -220, 0),
                  child: Text(
                    slide.desc,
                    style: GoogleFonts.poppins(fontSize: 14.5, color: AppColors.textGrey, height: 1.55),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
