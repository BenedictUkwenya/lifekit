import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../booking_progress.dart';

/// Compact 5-segment progress bar + "where it stands" label for list cards.
class BookingMiniProgress extends StatelessWidget {
  final Map booking;
  final bool isClient;

  const BookingMiniProgress({super.key, required this.booking, required this.isClient});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = computeBookingProgress(booking, isClient: isClient);
    final blocked = p.phase == BookingPhase.disputed || p.phase == BookingPhase.cancelled;
    final accent = switch (p.phase) {
      BookingPhase.completed => const Color(0xFF10B981),
      BookingPhase.disputed || BookingPhase.cancelled || BookingPhase.overdue => const Color(0xFFDC2626),
      _ => AppColors.primary,
    };
    final label = switch (p.phase) {
      BookingPhase.requested => l10n.trackStepConfirmedPending,
      BookingPhase.upcoming => l10n.trackHdrUpcomingTitle,
      BookingPhase.awaitingConfirmation =>
        p.iConfirmed ? l10n.trackHdrWaitingSub : l10n.trackHdrActionTitle,
      BookingPhase.overdue => l10n.trackHdrOverdueTitle,
      BookingPhase.completed => l10n.trackHdrCompletedTitle,
      BookingPhase.disputed => l10n.trackHdrDisputedTitle,
      BookingPhase.cancelled => l10n.trackHdrCancelledTitle,
    };
    final total = BookingStep.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 5,
                    color: Colors.grey.shade200,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        // done = full, current = partly filled (full when blocked), upcoming = empty
                        end: i < p.currentStep
                            ? 1
                            : i == p.currentStep
                                ? (blocked ? 1 : 0.45)
                                : 0,
                      ),
                      duration: Duration(milliseconds: 380 + i * 110),
                      curve: Motion.curve,
                      builder: (_, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(color: accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Pulse(
              active: p.myActionNeeded,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: accent),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
