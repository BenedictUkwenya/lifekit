import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'app_lottie.dart';
import 'motion.dart';

/// Friendly, animated "nothing here yet" state: an icon in a soft badge,
/// a title, an optional message and an optional call-to-action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional looping illustration shown instead of [icon].
  final AppAnim? anim;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (anim != null)
              AppLottie(anim!, size: 170).popIn()
            else
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    const Color(0xFF7C3AED).withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: Icon(icon, size: 42, color: AppColors.primary),
            ).popIn(),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ).fadeSlideIn(index: 1),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: Colors.grey[600]),
              ).fadeSlideIn(index: 2),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)).fadeSlideIn(index: 3),
            ],
          ],
        ),
      ),
    );
  }
}
