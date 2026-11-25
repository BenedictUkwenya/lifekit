import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';
import 'app_lottie.dart';

/// Full-screen "you did it!" moment: confetti rain, a bouncing card with an
/// animation, a title and a big chunky button. Used after the app's happy
/// moments (booked, paid, swap matched, review sent, money in).
class Celebrate {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    AppAnim anim = AppAnim.success,
    String? buttonLabel,
    bool confetti = true,
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, _, _) => _CelebrateView(
        title: title,
        message: message,
        anim: anim,
        buttonLabel: buttonLabel,
        confetti: confetti,
      ),
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.7, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.elasticOut, reverseCurve: Curves.easeIn)),
          child: child,
        ),
      ),
    );
  }
}

class _CelebrateView extends StatelessWidget {
  final String title;
  final String? message;
  final AppAnim anim;
  final String? buttonLabel;
  final bool confetti;

  const _CelebrateView({
    required this.title,
    required this.message,
    required this.anim,
    required this.buttonLabel,
    required this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        if (confetti && !still)
          const Positioned.fill(
            child: IgnorePointer(child: AppLottie(AppAnim.confetti, repeat: false, fit: BoxFit.cover)),
          ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLottie(anim, size: 170, repeat: anim != AppAnim.success),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  )
                      .animate(delay: 250.ms)
                      .fadeIn()
                      .scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 700.ms),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: AppColors.textGrey),
                    ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      key: const Key('celebrate_continue'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        (buttonLabel ?? l10n.continueButton).toUpperCase(),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white),
                      ),
                    ),
                  ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
