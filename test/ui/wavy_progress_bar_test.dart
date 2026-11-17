/// Test widget WavyProgressBar (ADR-007) — porting bar gelombang
/// dari nekios-mosque. Bar harus me-render CustomPaint (track +
/// gelombang + cursor) pada seluruh rentang fraksi — termasuk tepi
/// 0 (hanya track) dan 1 (cursor di ujung kanan) — tanpa exception,
/// dan tetap stabil saat fase animasi gelombang berjalan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/theme/theme.dart';
import 'package:nekios_school/ui/ui.dart';

Future<void> _pumpBar(WidgetTester tester, double progress) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: WavyProgressBar(
              progress: progress,
              activeColor: const Color(0xFF7BD9A8),
              trackColor: const Color(0xFFDFE9DF).withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('WavyProgressBar', () {
    for (final progress in [0.0, 0.44, 1.0]) {
      testWidgets('progress $progress: CustomPaint tampil, tanpa exception',
          (tester) async {
        await _pumpBar(tester, progress);
        expect(tester.takeException(), isNull);

        // Painter gelombang tinggal di dalam widget ini.
        expect(
          find.descendant(
            of: find.byType(WavyProgressBar),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );

        // Fase animasi berjalan (repaint 2800ms) tidak boleh error.
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('progress di luar rentang dijepit, tanpa exception',
        (tester) async {
      await _pumpBar(tester, 1.7);
      expect(tester.takeException(), isNull);
      await _pumpBar(tester, -0.3);
      expect(tester.takeException(), isNull);
    });
  });
}
