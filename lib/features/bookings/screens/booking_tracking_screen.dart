import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../reviews/screens/leave_review_screen.dart';
import '../../../core/widgets/motion.dart';
import '../booking_progress.dart';

class BookingTrackingScreen extends StatefulWidget {
  final dynamic booking;
  final bool isClient; // True if I am the customer, False if I am the provider

  const BookingTrackingScreen({
    super.key,
    required this.booking,
    required this.isClient,
  });

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  final ApiService _apiService = ApiService();
  late dynamic _currentBooking;
  bool _isLoading = false;
  bool _isDisputeSubmitting = false;
  bool _hasRated = false;
  final TextEditingController _disputeReasonController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  @override
  void dispose() {
    _disputeReasonController.dispose();
    super.dispose();
  }

  void _openDisputeSheet() {
    _disputeReasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).txReportIssue,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _disputeReasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Describe the issue",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isDisputeSubmitting
                          ? null
                          : () async {
                              final reason = _disputeReasonController.text
                                  .trim();
                              if (reason.isEmpty) {
                                AppToast.error(context, AppLocalizations.of(context).msgEnterReason);
                                return;
                              }

                              setSheetState(() => _isDisputeSubmitting = true);
                              try {
                                await _apiService.openBookingDispute(
                                  _currentBooking['id'],
                                  reason,
                                );
                                if (context.mounted) {
                                  setSheetState(
                                    () => _isDisputeSubmitting = false,
                                  );
                                  setState(() {
                                    _currentBooking['status'] = 'disputed';
                                  });
                                  Navigator.pop(context);
                                  if (!context.mounted) return;
                                  AppToast.success(context, AppLocalizations.of(context).disputeSubmitted);
                                }
                              } catch (e) {
                                setSheetState(
                                  () => _isDisputeSubmitting = false,
                                );
                                if (!context.mounted) return;
                                AppToast.error(context, appErrorMessage(context, e));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isDisputeSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context).txSubmitDispute,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // CALL THE NEW BACKEND ENDPOINT
  Future<void> _markAsComplete() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.completeBooking(_currentBooking['id']);

      // Refresh logic (In a real app, re-fetch booking details here)
      // For now, let's manually update UI based on logic
      setState(() {
        if (widget.isClient) {
          _currentBooking['client_confirmed'] = true;
        } else {
          _currentBooking['provider_confirmed'] = true;
        }

        // If both are true locally, set status to completed
        if (_currentBooking['client_confirmed'] == true &&
            _currentBooking['provider_confirmed'] == true) {
          _currentBooking['status'] = 'completed';
        }
        _isLoading = false;
      });

      if (!mounted) return;
      AppToast.success(context, AppLocalizations.of(context).confirmationSent);
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = '${_currentBooking['status'] ?? ''}';
    final progress = computeBookingProgress(
      _currentBooking as Map,
      isClient: widget.isClient,
    );
    final otherName = (_currentBooking['profiles']?['full_name'] ??
            (widget.isClient ? l10n.trackFallbackProvider : l10n.trackFallbackClient))
        .toString();
    final iHaveConfirmed = progress.iConfirmed;

    // Report/dispute is always available while the booking is still active
    final bool canReportIssue =
        status == 'confirmed' || status == 'pending' || status == 'accepted';

    // Provider confirmed but the client hasn't acted — 48h auto-release clock.
    final bool showEscrowWarning = widget.isClient &&
        _currentBooking['provider_confirmed'] == true &&
        _currentBooking['client_confirmed'] != true &&
        (status == 'confirmed' || status == 'pending');

    final bool canConfirm = !iHaveConfirmed &&
        (progress.phase == BookingPhase.upcoming ||
            progress.phase == BookingPhase.awaitingConfirmation ||
            progress.phase == BookingPhase.overdue);
    final bool waitingOnOther = iHaveConfirmed &&
        progress.phase != BookingPhase.completed &&
        progress.phase != BookingPhase.disputed &&
        progress.phase != BookingPhase.cancelled;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: Text(l10n.trackTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusHero(
              progress: progress,
              isClient: widget.isClient,
              otherName: otherName,
            ),
            if (showEscrowWarning) ...[
              const SizedBox(height: 14),
              _Banner(
                color: Colors.orange,
                icon: Icons.access_time_filled_rounded,
                title: l10n.trackEscrowTitle,
                body: l10n.trackEscrowBody,
              ).fadeSlideIn(index: 1),
            ],
            const SizedBox(height: 14),
            _FactsCard(
              otherName: otherName,
              scheduledAt: progress.scheduledAt,
              amount: num.tryParse('${_currentBooking['total_price']}') ?? 0,
              isSwap: progress.isSwap,
            ).fadeSlideIn(index: 2),
            const SizedBox(height: 14),
            _Timeline(progress: progress, otherName: otherName).fadeSlideIn(index: 3),
            const SizedBox(height: 24),

            // ── Primary action ────────────────────────────────────────────
            AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.curve,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
              ),
              child: canConfirm
                  ? SizedBox(
                      key: const ValueKey('confirm'),
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _markAsComplete,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.task_alt_rounded),
                        label: Text(widget.isClient ? l10n.trackMarkReceived : l10n.trackMarkDone),
                      ),
                    )
                  : waitingOnOther
                      ? Container(
                          key: const ValueKey('waiting'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.trackYouConfirmed(otherName),
                                  style: GoogleFonts.poppins(color: const Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
            ),
            if (canConfirm || waitingOnOther) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      progress.isSwap ? l10n.trackSwapInfo : l10n.trackEscrowInfo,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],

            // ── Rate (once you've confirmed your side or it's completed) ──
            if (!_hasRated && (iHaveConfirmed || status == 'completed')) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final revieweeId = widget.isClient
                        ? _currentBooking['provider_id']?.toString() ?? ''
                        : _currentBooking['client_id']?.toString() ?? '';
                    final reviewerRole = widget.isClient ? 'client' : 'provider';
                    final rated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveReviewScreen(
                          bookingId: _currentBooking['id'],
                          serviceId: _currentBooking['service_id'] ?? '',
                          revieweeId: revieweeId,
                          reviewerRole: reviewerRole,
                          revieweeName: otherName,
                        ),
                      ),
                    );
                    if (rated == true && mounted) {
                      setState(() => _hasRated = true);
                    }
                  },
                  icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                  label: Text(widget.isClient ? l10n.trackRateProvider : l10n.trackRateClient),
                ),
              ).fadeSlideIn(index: 4),
            ],

            if (canReportIssue) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _openDisputeSheet,
                style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                icon: Icon(
                  progress.phase == BookingPhase.overdue
                      ? Icons.report_problem_rounded
                      : Icons.flag_outlined,
                  size: 18,
                ),
                label: Text(l10n.trackReportIssue),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Status hero — the big coloured card that says where things stand.
// ═══════════════════════════════════════════════════════════════════════════
class _HeroStyle {
  final List<Color> colors;
  final IconData icon;
  final String title;
  final String subtitle;

  const _HeroStyle(this.colors, this.icon, this.title, this.subtitle);
}

class _StatusHero extends StatelessWidget {
  final BookingProgress progress;
  final bool isClient;
  final String otherName;

  const _StatusHero({required this.progress, required this.isClient, required this.otherName});

  _HeroStyle _style(AppLocalizations l10n) {
    switch (progress.phase) {
      case BookingPhase.requested:
        return isClient
            ? _HeroStyle(const [Color(0xFFF59E0B), Color(0xFFEA580C)], Icons.hourglass_top_rounded,
                l10n.trackHdrRequestedTitle, l10n.trackHdrRequestedSub)
            : _HeroStyle(const [Color(0xFF89273B), Color(0xFFB4405A)], Icons.mark_email_unread_rounded,
                l10n.trackHdrNewRequestTitle, l10n.trackHdrNewRequestSub);
      case BookingPhase.upcoming:
        return _HeroStyle(const [Color(0xFF4F46E5), Color(0xFF7C3AED)], Icons.event_available_rounded,
            l10n.trackHdrUpcomingTitle, l10n.trackHdrUpcomingSub);
      case BookingPhase.awaitingConfirmation:
        return progress.iConfirmed
            ? _HeroStyle(const [Color(0xFF2563EB), Color(0xFF0EA5E9)], Icons.hourglass_bottom_rounded,
                l10n.trackHdrWaitingTitle(otherName), l10n.trackHdrWaitingSub)
            : _HeroStyle(const [Color(0xFF89273B), Color(0xFFB4405A)], Icons.touch_app_rounded,
                l10n.trackHdrActionTitle,
                isClient ? l10n.trackHdrActionClientSub : l10n.trackHdrActionProviderSub);
      case BookingPhase.overdue:
        return _HeroStyle(const [Color(0xFFDC2626), Color(0xFFF97316)], Icons.warning_amber_rounded,
            l10n.trackHdrOverdueTitle, l10n.trackHdrOverdueSub);
      case BookingPhase.completed:
        return _HeroStyle(const [Color(0xFF059669), Color(0xFF10B981)], Icons.check_circle_rounded,
            l10n.trackHdrCompletedTitle,
            progress.isSwap ? l10n.trackHdrSwapCompletedSub : l10n.trackHdrCompletedSub);
      case BookingPhase.disputed:
        return _HeroStyle(const [Color(0xFFB91C1C), Color(0xFF7F1D1D)], Icons.gavel_rounded,
            l10n.trackHdrDisputedTitle, l10n.trackHdrDisputedSub);
      case BookingPhase.cancelled:
        return _HeroStyle(const [Color(0xFF6B7280), Color(0xFF374151)], Icons.cancel_rounded,
            l10n.trackHdrCancelledTitle, l10n.trackHdrCancelledSub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _style(l10n);
    final showCountdown = progress.phase == BookingPhase.upcoming && progress.scheduledAt != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: s.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: s.colors.first.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative circles for depth
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pulse(
                active: progress.myActionNeeded,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(s.icon, color: Colors.white, size: 30),
                ),
              ).popIn(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
                    const SizedBox(height: 6),
                    Text(s.subtitle,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.4)),
                    if (showCountdown) ...[
                      const SizedBox(height: 12),
                      _Countdown(target: progress.scheduledAt!),
                    ],
                  ],
                ).fadeSlideIn(index: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "in 2d 4h" chip that refreshes every 30 seconds.
class _Countdown extends StatefulWidget {
  final DateTime target;

  const _Countdown({required this.target});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = widget.target.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();
    final text = left.inDays >= 1
        ? l10n.trackInDays(left.inDays, left.inHours % 24)
        : left.inHours >= 1
            ? l10n.trackInHours(left.inHours, left.inMinutes % 60)
            : l10n.trackInMinutes(left.inMinutes.clamp(1, 59));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: Text(text,
                key: ValueKey(text),
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Facts: who, when, how much.
// ═══════════════════════════════════════════════════════════════════════════
class _FactsCard extends StatelessWidget {
  final String otherName;
  final DateTime? scheduledAt;
  final num amount;
  final bool isSwap;

  const _FactsCard({
    required this.otherName,
    required this.scheduledAt,
    required this.amount,
    required this.isSwap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    Widget fact(IconData icon, String label, Widget value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                ),
              ]),
              const SizedBox(height: 4),
              value,
            ],
          ),
        );
    final valueStyle = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fact(Icons.person_outline_rounded, l10n.trackWith,
              Text(otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle)),
          fact(Icons.event_outlined, l10n.trackScheduled,
              Text(scheduledAt == null ? '—' : DateFormat('d MMM, HH:mm', lang).format(scheduledAt!), style: valueStyle)),
          fact(isSwap ? Icons.swap_horiz_rounded : Icons.payments_outlined, l10n.trackAmount,
              isSwap
                  ? Text(l10n.trackSkillSwap, style: valueStyle.copyWith(color: AppColors.primary))
                  : AnimatedCount(
                      value: amount.toDouble(),
                      format: (v) => '\$${v.toStringAsFixed(2)}',
                      style: valueStyle.copyWith(color: AppColors.primary),
                    )),
        ],
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6)),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// Animated vertical timeline.
// ═══════════════════════════════════════════════════════════════════════════
class _Timeline extends StatelessWidget {
  final BookingProgress progress;
  final String otherName;

  const _Timeline({required this.progress, required this.otherName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = progress;

    (String, String) text(BookingStep s) {
      switch (s) {
        case BookingStep.requested:
          return (l10n.trackStepRequested, l10n.trackStepRequestedSub);
        case BookingStep.confirmed:
          return (l10n.trackStepConfirmed, p.isDone(s) ? l10n.trackStepConfirmedSub : l10n.trackStepConfirmedPending);
        case BookingStep.serviceDay:
          return (
            l10n.trackStepServiceDay,
            p.scheduledAt == null ? '—' : DateFormat('EEE, d MMM · HH:mm', lang).format(p.scheduledAt!),
          );
        case BookingStep.bothConfirm:
          return (
            l10n.trackStepBothConfirm,
            p.isDone(s)
                ? l10n.trackStepBothConfirmDone
                : !p.iConfirmed
                    ? l10n.trackStepWaitingYou
                    : l10n.trackStepWaitingOther(otherName),
          );
        case BookingStep.paidOut:
          return p.isSwap
              ? (l10n.trackStepSwapDone, l10n.trackStepSwapDoneSub)
              : (l10n.trackStepPaidOut, l10n.trackStepPaidOutSub);
      }
    }

    final steps = BookingStep.values;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              index: i,
              title: text(steps[i]).$1,
              subtitle: text(steps[i]).$2,
              state: p.isDone(steps[i])
                  ? _StepState.done
                  : p.isCurrent(steps[i])
                      ? (p.phase == BookingPhase.disputed || p.phase == BookingPhase.cancelled
                          ? _StepState.blocked
                          : _StepState.current)
                      : _StepState.upcoming,
              blockedIcon: p.phase == BookingPhase.disputed ? Icons.gavel_rounded : Icons.close_rounded,
              isLast: i == steps.length - 1,
              lineFilled: p.isDone(steps[i]),
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming, blocked }

class _TimelineRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final _StepState state;
  final IconData blockedIcon;
  final bool isLast;
  final bool lineFilled;

  const _TimelineRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.blockedIcon,
    required this.isLast,
    required this.lineFilled,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);
    const red = Color(0xFFDC2626);
    final delay = Duration(milliseconds: 150 + index * 140);

    Widget dot;
    switch (state) {
      case _StepState.done:
        dot = Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ).popIn(delay: delay);
      case _StepState.current:
        dot = Pulse(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12)],
            ),
            child: Center(
              child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ),
        );
      case _StepState.blocked:
        dot = Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
          child: Icon(blockedIcon, size: 16, color: Colors.white),
        ).popIn(delay: delay);
      case _StepState.upcoming:
        dot = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
        );
    }

    final titleColor = state == _StepState.upcoming ? Colors.grey[400] : AppColors.textDark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                      alignment: Alignment.topCenter,
                      child: lineFilled
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 420 + index * 140),
                              curve: Motion.curve,
                              builder: (_, v, _) => FractionallySizedBox(
                                heightFactor: v,
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(2)),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 12 : 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: state == _StepState.current ? FontWeight.w700 : FontWeight.w600,
                        color: titleColor,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: state == _StepState.current
                            ? AppColors.primary
                            : state == _StepState.blocked
                                ? red
                                : Colors.grey[500],
                        fontWeight: state == _StepState.current ? FontWeight.w500 : FontWeight.w400,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    ).fadeSlideIn(index: index);
  }
}

class _Banner extends StatelessWidget {
  final MaterialColor color;
  final IconData icon;
  final String title;
  final String body;

  const _Banner({required this.color, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: color.shade900, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(body, style: GoogleFonts.poppins(color: color.shade900, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
