import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/features/home/daily_plan.dart';

void main() {
  final start = DateTime(2026, 10, 20, 21, 30); // evening of day 1

  Map<String, dynamic> profile({Set<int> done = const {}, bool legacy = false}) => {
        'created_at': DateTime(2026, 9, 1).toIso8601String(),
        'onboarding_plan': [
          for (var d = 1; d <= 7; d++)
            {
              'day': d,
              'task': 'Task $d',
              'action_route': d == 2 ? 'profile' : 'none',
              if (!legacy) 'started_at': start.toIso8601String(),
              'done_at': done.contains(d) ? start.toIso8601String() : null,
            },
        ],
      };

  test('no plan → null', () {
    expect(DailyPlan.fromProfile({'onboarding_plan': null}), isNull);
    expect(DailyPlan.fromProfile(null), isNull);
  });

  test('day 1 on the start date, day 2 the next calendar day', () {
    final p1 = DailyPlan.fromProfile(profile(), now: DateTime(2026, 10, 20, 23))!;
    expect(p1.unlockedCount, 1);
    expect(p1.current!.day, 1);
    // Only ~3h later, but it's a new calendar day.
    final p2 = DailyPlan.fromProfile(profile(), now: DateTime(2026, 10, 21, 0, 30))!;
    expect(p2.unlockedCount, 2);
  });

  test('missed days carry forward instead of vanishing', () {
    final p = DailyPlan.fromProfile(profile(done: {1}), now: DateTime(2026, 10, 24))!;
    expect(p.unlockedCount, 5);
    expect(p.current!.day, 2);
    expect(p.statusOf(p.days[3]), DayStatus.unlocked);
    expect(p.statusOf(p.days[6]), DayStatus.locked);
  });

  test('caught up when everything unlocked is done', () {
    final p = DailyPlan.fromProfile(profile(done: {1, 2}), now: DateTime(2026, 10, 21, 12))!;
    expect(p.current, isNull);
    expect(p.caughtUp, isTrue);
    expect(p.isComplete, isFalse);
  });

  test('complete after all 7 and capped at day 7', () {
    final p = DailyPlan.fromProfile(profile(done: {1, 2, 3, 4, 5, 6, 7}), now: DateTime(2026, 12, 1))!;
    expect(p.unlockedCount, 7);
    expect(p.isComplete, isTrue);
    expect(p.caughtUp, isFalse);
    expect(p.doneCount, 7);
  });

  test('legacy plan without started_at uses account creation date', () {
    final p = DailyPlan.fromProfile(profile(legacy: true), now: DateTime(2026, 10, 20))!;
    expect(p.unlockedCount, 7);
    expect(p.current!.day, 1);
  });
}
