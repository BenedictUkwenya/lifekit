/// Gracia's 7-day plan: which day is unlocked, which task is current, and
/// overall progress. Pure logic so it can be unit-tested.
library;

class PlanDay {
  final int day; // 1-7
  final String task;
  final String actionRoute;
  final DateTime? doneAt;

  const PlanDay({required this.day, required this.task, required this.actionRoute, this.doneAt});

  bool get isDone => doneAt != null;
}

enum DayStatus { done, current, unlocked, locked }

class DailyPlan {
  final List<PlanDay> days;
  final DateTime startedAt;

  /// How many days are open today (1 on the start date … 7).
  final int unlockedCount;

  const DailyPlan._(this.days, this.startedAt, this.unlockedCount);

  /// Builds the plan from the profile's `onboarding_plan`. Older plans have
  /// no `started_at`, so [profileCreatedAt] is used instead.
  static DailyPlan? fromProfile(
    Map<String, dynamic>? profile, {
    DateTime? now,
  }) {
    final raw = profile?['onboarding_plan'];
    if (raw is! List || raw.isEmpty) return null;
    now ??= DateTime.now();

    final days = <PlanDay>[];
    for (var i = 0; i < raw.length && i < 7; i++) {
      final d = raw[i];
      if (d is! Map) continue;
      days.add(PlanDay(
        day: int.tryParse('${d['day']}') ?? i + 1,
        task: '${d['task'] ?? ''}',
        actionRoute: '${d['action_route'] ?? 'none'}',
        doneAt: DateTime.tryParse('${d['done_at'] ?? ''}'),
      ));
    }
    if (days.isEmpty) return null;

    final first = raw.first is Map ? raw.first as Map : const {};
    final started = DateTime.tryParse('${first['started_at'] ?? ''}')?.toLocal() ??
        DateTime.tryParse('${profile?['created_at'] ?? ''}')?.toLocal() ??
        now;

    // Calendar days in the user's timezone, not 24-hour periods.
    final startDay = DateTime(started.year, started.month, started.day);
    final today = DateTime(now.year, now.month, now.day);
    final elapsed = today.difference(startDay).inDays;
    return DailyPlan._(days, started, (elapsed + 1).clamp(1, days.length));
  }

  int get doneCount => days.where((d) => d.isDone).length;
  bool get isComplete => doneCount == days.length;

  /// Earliest unlocked day that isn't done — missed days carry forward.
  PlanDay? get current {
    for (var i = 0; i < unlockedCount; i++) {
      if (!days[i].isDone) return days[i];
    }
    return null;
  }

  /// Everything unlocked so far is done, but the plan isn't finished.
  bool get caughtUp => current == null && !isComplete;

  DayStatus statusOf(PlanDay d) {
    if (d.isDone) return DayStatus.done;
    if (d == current) return DayStatus.current;
    final index = days.indexOf(d);
    return index < unlockedCount ? DayStatus.unlocked : DayStatus.locked;
  }
}
