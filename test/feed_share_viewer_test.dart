import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/core/utils/share_text.dart';
import 'package:lifekit_frontend/features/home/widgets/photo_viewer.dart';

void main() {
  testWidgets('shareText always sends a non-empty on-screen anchor (iOS 26 / iPad)', (t) async {
    final calls = <MethodCall>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        calls.add(call);
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null));

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => shareText(ctx, 'Hello from LifeKit'),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Share'));
    await t.pump();

    expect(calls, isNotEmpty);
    final args = Map<String, dynamic>.from(calls.last.arguments as Map);
    expect(args['text'], 'Hello from LifeKit');
    expect((args['originWidth'] as num) > 0, isTrue);
    expect((args['originHeight'] as num) > 0, isTrue);
  });

  testWidgets('photo viewer opens on the tapped photo, counts, and closes', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => PhotoViewer.open(ctx, const ['https://x/a.jpg', 'https://x/b.jpg'], index: 1),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('2 / 2'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 2'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
