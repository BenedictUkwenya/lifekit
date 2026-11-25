// Dev-only: renders frames of Lottie files to PNG contact sheets so animations
// can be checked by eye. Run with:
//   flutter test test/lottie_preview_test.dart --dart-define=LOTTIE_IN=<dir> --dart-define=LOTTIE_OUT=<dir>
// Skipped when LOTTIE_IN is not given, so it never runs in the normal suite.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const _in = String.fromEnvironment('LOTTIE_IN');
const _out = String.fromEnvironment('LOTTIE_OUT');

void main() {
  testWidgets('render lottie contact sheets', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory(_in);
      final outDir = Directory(_out)..createSync(recursive: true);
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      // Sheets of up to 8 animations: one row each, 5 frames per row.
      const cell = 120.0;
      const frames = [0.15, 0.35, 0.55, 0.8, 1.0];
      const perSheet = 8;
      final index = StringBuffer();
      for (var s = 0; s * perSheet < files.length; s++) {
        final batch = files.skip(s * perSheet).take(perSheet).toList();
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        final w = cell * frames.length, h = cell * batch.length;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFFFFFFF));
        for (var r = 0; r < batch.length; r++) {
          final f = batch[r];
          index.writeln('sheet$s row$r ${f.uri.pathSegments.last}');
          if (r > 0) {
            canvas.drawLine(Offset(0, r * cell), Offset(w, r * cell), Paint()..color = const Color(0xFFDDDDDD));
          }
          try {
            final comp = await LottieComposition.fromBytes(await f.readAsBytes());
            final drawable = LottieDrawable(comp);
            for (var i = 0; i < frames.length; i++) {
              drawable.setProgress(frames[i]);
              drawable.draw(canvas, Rect.fromLTWH(i * cell, r * cell, cell, cell));
            }
          } catch (e) {
            index.writeln('  FAILED: $e');
          }
        }
        final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${outDir.path}/sheet$s.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      File('${outDir.path}/index.txt').writeAsStringSync(index.toString());
    });
  }, skip: _in.isEmpty);
}
