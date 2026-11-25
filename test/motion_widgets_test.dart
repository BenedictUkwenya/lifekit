import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifekit_frontend/core/theme/app_theme.dart';
import 'package:lifekit_frontend/core/widgets/app_lottie.dart';
import 'package:lifekit_frontend/core/widgets/celebrate.dart';
import 'package:lifekit_frontend/core/widgets/chunky.dart';
import 'package:lifekit_frontend/core/widgets/empty_state.dart';
import 'package:lifekit_frontend/core/widgets/lifekit_loader.dart';
import 'package:lifekit_frontend/core/widgets/motion.dart';
import 'package:lifekit_frontend/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Runs until animations settle or [max] passes (Lottie loops never settle).
Future<void> _run(WidgetTester t, [Duration max = const Duration(seconds: 3)]) async {
  for (var waited = Duration.zero; waited < max; waited += const Duration(milliseconds: 100)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('chunky buttons', () {
    test('wraps rounded shapes in a ledge and leaves circles alone', () {
      final rounded = chunky(ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      final idle = rounded.shape!.resolve({});
      final pressed = rounded.shape!.resolve({WidgetState.pressed});
      final disabled = rounded.shape!.resolve({WidgetState.disabled});
      expect(idle, isA<LedgeBorder>());
      expect((idle as LedgeBorder).depth, 4);
      expect((pressed as LedgeBorder).depth, 0);
      expect((disabled as LedgeBorder).depth, 0);
      expect(idle.borderRadius, BorderRadius.circular(12));

      final circle = chunky(ElevatedButton.styleFrom(shape: const CircleBorder()));
      expect(circle.shape!.resolve({}), isA<CircleBorder>());
    });

    test('keeps the outline when the button sets a side', () {
      const side = BorderSide(color: Colors.red, width: 2);
      final s = chunky(OutlinedButton.styleFrom(shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: side)));
      final b = s.shape!.resolve({}) as LedgeBorder;
      expect(b.side, side);
      expect(b.copyWith(side: BorderSide.none).side, BorderSide.none);
      final mid = b.lerpTo(b.copyWith(depth: 0), 0.5) as LedgeBorder;
      expect(mid.depth, 2);
    });

    testWidgets('a themed button sinks while pressed and still taps', (t) async {
      var taps = 0;
      await t.pumpWidget(_app(Center(
        child: ElevatedButton(onPressed: () => taps++, child: const Text('Book')),
      )));
      final gesture = await t.startGesture(t.getCenter(find.text('Book')));
      await t.pump(const Duration(milliseconds: 150));
      final material = t.widget<Material>(
          find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first);
      expect((material.shape as LedgeBorder).depth, 0);
      await gesture.up();
      await t.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      final after = t.widget<Material>(
          find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first);
      expect((after.shape as LedgeBorder).depth, 4);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('celebration shows, plays, and closes on Continue', (t) async {
    await t.pumpWidget(_app(Builder(
      builder: (ctx) => ElevatedButton(
        onPressed: () => Celebrate.show(ctx, title: 'Booked!', message: 'See you soon', anim: AppAnim.handshake),
        child: const Text('go'),
      ),
    )));
    await t.tap(find.text('go'));
    await _run(t);
    expect(find.text('Booked!'), findsOneWidget);
    expect(find.text('See you soon'), findsOneWidget);
    await t.tap(find.byKey(const Key('celebrate_continue')));
    await _run(t, const Duration(seconds: 1));
    expect(find.text('Booked!'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('every Lottie file loads and plays', (t) async {
    for (final a in AppAnim.values) {
      await t.pumpWidget(_app(Center(child: AppLottie(a, size: 120))));
      await _run(t, const Duration(milliseconds: 600));
      expect(t.takeException(), isNull, reason: a.file);
    }
  });

  testWidgets('reduce motion shows a still frame', (t) async {
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: _app(const Center(child: AppLottie(AppAnim.success, size: 100))),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
  });

  testWidgets('empty state with an animation renders', (t) async {
    await t.pumpWidget(_app(const EmptyState(
      icon: Icons.inbox, title: 'Nothing yet', message: 'Come back later', anim: AppAnim.emptyBox)));
    await _run(t, const Duration(seconds: 1));
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('bouncing loader runs without errors', (t) async {
    await t.pumpWidget(_app(const LifeKitLoader(showSlowHint: false)));
    await _run(t, const Duration(seconds: 2));
    expect(t.takeException(), isNull);
  });

  testWidgets('cascading list items all end up visible', (t) async {
    await t.pumpWidget(_app(ListView.builder(
      itemCount: 30,
      itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')).cascadeIn(i),
    )));
    await _run(t, const Duration(seconds: 2));
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 9'), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, -800));
    await _run(t, const Duration(seconds: 1));
    expect(find.text('row 25'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
