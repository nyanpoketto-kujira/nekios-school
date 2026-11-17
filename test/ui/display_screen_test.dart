import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
import 'package:nekios_school/ui/ui.dart';

JadwalData muatDataAsli() => JadwalData.fromJson(
      jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
          as Map<String, dynamic>,
    );

DisplayStore storePada(DateTime now) {
  final store = DisplayStore();
  store.terima(ScheduleReplaced(muatDataAsli()));
  store.tick(now);
  return store;
}

void aturLayarTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('DisplayScreen', () {
    testWidgets('tanpa data: tampil memuat, tidak crash', (tester) async {
      aturLayarTv(tester);
      final store = DisplayStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: DisplayScreen(store: store)));
      expect(find.text('Memuat jadwal…'), findsOneWidget);
    });

    testWidgets(
        'Selasa 09:20: kartu halaman 1 + countdown, lalu rotasi ke halaman 2',
        (tester) async {
      aturLayarTv(tester);
      // Selasa 2026-11-17 09:20:24 — skenario desain Varian J/Rotasi.
      final store = storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();

      // Header + strip (strip HANYA di layout Pelajaran, ADR-008).
      expect(find.text('SMKN 1 UKUI'), findsOneWidget);
      expect(find.text('09:20:24'), findsOneWidget);
      expect(find.byType(StripStatusBel), findsOneWidget);
      expect(find.text('24:36'), findsOneWidget);
      // Chip strip + label baris aktif di timeline.
      expect(find.text('SEDANG BERLANGSUNG'), findsNWidgets(2));

      // Kartu halaman 1: X TKJ A, X TKJ B, XI TKJ A.
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsOneWidget);
      expect(find.text('Dasar-Dasar Program Keahlian'), findsOneWidget);
      expect(find.text('Bahasa Indonesia'), findsOneWidget);
      expect(find.text('XII TKJ A'), findsNothing);

      // Rotasi 12 detik → halaman 2 (XI TKJ B, XII TKJ A, XII TKJ B).
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Bahasa Inggris'), findsOneWidget);
      expect(find.text('Konsentrasi Keahlian TKJ'), findsWidgets);
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsNothing);
    });

    testWidgets(
        'Selasa 12:20 ISOMA: hero tampil TANPA strip — info tidak dobel '
        '(ADR-008)', (tester) async {
      aturLayarTv(tester);
      final store = storePada(DateTime(2026, 11, 17, 12, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();

      // Hero tetap tampil dengan kata statusnya.
      expect(find.text('ISOMA'), findsOneWidget);
      expect(find.textContaining('ISOMA'), findsWidgets);
      // Strip TIDAK dirender pada status hero: countdown kini muncul
      // SEKALI (di hero) dan chip bel milik strip tidak ada. (Dulu
      // '24:36' findsWidgets karena strip + hero sama-sama tampil.)
      expect(find.byType(StripStatusBel), findsNothing);
      expect(find.text('24:36'), findsOneWidget);
      expect(find.text('BEL • 12.45'), findsNothing);
    });

    testWidgets('Selasa 15:50 pulang: hero tampil, tidak crash',
        (tester) async {
      aturLayarTv(tester);
      final store = storePada(DateTime(2026, 11, 17, 15, 50));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();

      expect(find.text('SAMPAI JUMPA BESOK'), findsOneWidget);
    });
  });
}
