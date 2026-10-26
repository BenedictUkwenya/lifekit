import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../daily_plan.dart';
import '../plan_actions.dart';

/// Home-screen card for Gracia's 7-day plan: today's task, progress dots,
/// "Do it" / "Mark done", and a sheet with every day. Progress is saved to
/// the account via the API, so it follows the user across devices.
class DailyPlanCard extends StatefulWidget {
  final Map<String, dynamic>? profile;

  /// Called with the updated plan after the user marks a day.
  final ValueChanged<List<dynamic>> onPlanUpdated;

  const DailyPlanCard({super.key, required this.profile, required this.onPlanUpdated});

  @override
  State<DailyPlanCard> createState() => _DailyPlanCardState();
}

class _DailyPlanCardState extends State<DailyPlanCard> {
  final _api = ApiService();
  bool _busy = false;
  bool _completeDismissed = false;

  String get _dismissKey {
    final first = (widget.profile?['onboarding_plan'] as List?)?.firstOrNull;
    final started = first is Map ? first['started_at'] : null;
    return 'plan_done_dismissed_${widget.profile?['id']}_${started ?? 'legacy'}';
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted && p.getBool(_dismissKey) == true) setState(() => _completeDismissed = true);
    });
  }

  Future<void> _setDone(PlanDay day, bool done) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    if (done) HapticFeedback.mediumImpact();
    try {
      final plan = await _api.setPlanDayDone(day.day, done);
      if (!mounted) return;
      widget.onPlanUpdated(plan);
      if (done) AppToast.success(context, l10n.planDayDoneToast(day.day));
    } catch (e) {
      if (mounted) AppToast.error(context, appErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissComplete() async {
    setState(() => _completeDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey, true);
  }

  void _openSheet(DailyPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanSheet(
        profile: widget.profile,
        onToggle: (day, done) async {
          await _setDone(day, done);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = DailyPlan.fromProfile(widget.profile);
    if (plan == null) return const SizedBox.shrink();
    if (plan.isComplete && _completeDismissed) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.curve,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey('${plan.doneCount}-${plan.current?.day}-${plan.isComplete}'),
        child: plan.isComplete
            ? _completeCard(plan)
            : plan.caughtUp
                ? _caughtUpCard(plan)
                : _taskCard(plan),
      ),
    );
  }

  // ── Card states ──────────────────────────────────────────────────────────

  Widget _taskCard(DailyPlan plan) {
    final l10n = AppLocalizations.of(context);
    final day = plan.current!;
    final behind = plan.unlockedCount > day.day; // a missed day carried forward
    return Pressable(
      pressedScale: 0.98,
      onTap: () => _openSheet(plan),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _gradient(const [AppColors.primary, Color(0xFF7C3AED)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.homeDailyTaskTitle,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                _chip(behind ? l10n.planCatchUp : l10n.planDayOf(day.day, plan.days.length)),
              ],
            ),
            const SizedBox(height: 12),
            _Dots(plan: plan),
            const SizedBox(height: 12),
            Text(day.task,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.45)),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(l10n.planProgress(plan.doneCount, plan.days.length),
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                if (planActionAvailable(day.actionRoute)) ...[
                  _button(
                    label: l10n.planDoIt,
                    icon: Icons.arrow_forward_rounded,
                    filled: false,
                    onTap: () => openPlanAction(context, day.actionRoute),
                  ),
                  const SizedBox(width: 8),
                ],
                _button(
                  label: l10n.homeDailyTaskMarkDone,
                  icon: Icons.check_rounded,
                  filled: true,
                  onTap: () => _setDone(day, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _caughtUpCard(DailyPlan plan) {
    final l10n = AppLocalizations.of(context);
    return Pressable(
      pressedScale: 0.98,
      onTap: () => _openSheet(plan),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22).popIn(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.planCaughtUp,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Dots(plan: plan, onLight: true),
          ],
        ),
      ),
    );
  }

  Widget _completeCard(DailyPlan plan) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 18),
      decoration: _gradient(const [Color(0xFF059669), Color(0xFF10B981)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 34)).popIn(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.planCompleteTitle,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l10n.planCompleteBody,
                    style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          IconButton(
            onPressed: _dismissComplete,
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Bits ─────────────────────────────────────────────────────────────────

  BoxDecoration _gradient(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _button({required String label, required IconData icon, required bool filled, required VoidCallback onTap}) {
    return Pressable(
      onTap: _busy ? null : onTap,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: _busy ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy && filled)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(icon, size: 16, color: filled ? AppColors.primary : Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: filled ? AppColors.primary : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seven progress dots: ✓ done, pulsing current, faint locked.
class _Dots extends StatelessWidget {
  final DailyPlan plan;
  final bool onLight;

  const _Dots({required this.plan, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final base = onLight ? const Color(0xFF10B981) : Colors.white;
    return Row(
      children: [
        for (final d in plan.days) ...[
          Expanded(
            child: Builder(builder: (_) {
              final status = plan.statusOf(d);
              final dot = AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                height: 22,
                decoration: BoxDecoration(
                  color: switch (status) {
                    DayStatus.done => base,
                    DayStatus.current => base.withValues(alpha: 0.35),
                    DayStatus.unlocked => base.withValues(alpha: 0.22),
                    DayStatus.locked => base.withValues(alpha: onLight ? 0.12 : 0.1),
                  },
                  borderRadius: BorderRadius.circular(8),
                  border: status == DayStatus.current ? Border.all(color: base, width: 1.5) : null,
                ),
                alignment: Alignment.center,
                child: status == DayStatus.done
                    ? Icon(Icons.check_rounded, size: 14, color: onLight ? Colors.white : AppColors.primary).popIn()
                    : Text('${d.day}',
                        style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: onLight ? AppColors.textDark.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.85))),
              );
              return status == DayStatus.current ? Pulse(child: dot) : dot;
            }),
          ),
          if (d != plan.days.last) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

/// Bottom sheet listing every day with its status. Unlocked days can be
/// toggled; locked ones show when they open.
class _PlanSheet extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final Future<void> Function(PlanDay day, bool done) onToggle;

  const _PlanSheet({required this.profile, required this.onToggle});

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  int? _busyDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = DailyPlan.fromProfile(widget.profile);
    if (plan == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(l10n.planSheetTitle, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
              Text(l10n.planProgress(plan.doneCount, plan.days.length),
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: plan.doneCount / plan.days.length),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < plan.days.length; i++)
            _row(plan, plan.days[i], l10n).fadeSlideIn(index: i),
        ],
      ),
    );
  }

  Widget _row(DailyPlan plan, PlanDay d, AppLocalizations l10n) {
    final status = plan.statusOf(d);
    final locked = status == DayStatus.locked;
    final color = switch (status) {
      DayStatus.done => const Color(0xFF10B981),
      DayStatus.current => AppColors.primary,
      _ => Colors.grey.shade400,
    };
    final label = switch (status) {
      DayStatus.done => l10n.planDone,
      DayStatus.current => l10n.planToday,
      DayStatus.unlocked => l10n.planCatchUp,
      DayStatus.locked => l10n.planLocked,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: status == DayStatus.current ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: status == DayStatus.current ? 0.5 : 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: status == DayStatus.done ? color : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: status == DayStatus.done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : locked
                        ? Icon(Icons.lock_outline_rounded, color: color, size: 16)
                        : Text('${d.day}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l10n.planDayOf(d.day, plan.days.length),
                            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        Text('· $label', style: GoogleFonts.poppins(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(d.task,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          decoration: status == DayStatus.done ? TextDecoration.lineThrough : null,
                          color: status == DayStatus.done ? Colors.grey[500] : AppColors.textDark,
                        )),
                    if (!locked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (planActionAvailable(d.actionRoute) && status != DayStatus.done)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                              onPressed: () {
                                Navigator.pop(context);
                                openPlanAction(context, d.actionRoute);
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: Text(l10n.planDoIt),
                            ),
                          const Spacer(),
                          _busyDay == d.day
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: status == DayStatus.done ? Colors.grey[600] : const Color(0xFF10B981)),
                                  onPressed: () async {
                                    setState(() => _busyDay = d.day);
                                    await widget.onToggle(d, !d.isDone);
                                    if (mounted) Navigator.pop(context);
                                  },
                                  child: Text(status == DayStatus.done ? l10n.planUndo : l10n.homeDailyTaskMarkDone),
                                ),
                        ],
                      ),
                    ],
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
