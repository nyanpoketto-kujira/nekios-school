/// Test regresi overflow 1920×1080 (perbaikan pasca-redesign ADR-006).
///
/// Bug asal: screenshot emulator TV menunjukkan "BOTTOM OVERFLOWED BY
/// 87 PIXELS" pada status Pelajaran — Column layar pelajaran
/// menjumlahkan tinggi tetap (header + strip + kartu 216 + progres +
/// indikator + celah = 535) melebihi ruang yang tersedia.
///
/// Dua jebakan yang membuat test lama lolos:
/// 1. TV melaporkan 1920×1080 piksel FISIK pada devicePixelRatio 2.0,
///    jadi viewport LOGISnya 960×540 — ruang vertikal logis hanya
///    separuh dari yang diasumsikan test lama (1920×1080 @ DPR 1.0).
/// 2. Test lama mem-pump MaterialApp tanpa tema asli aplikasi.
///
/// Test di sini mem-pump DisplayScreen dengan tema asli
/// (AppTheme.darkTheme, sama seperti main.dart) pada kedua rasio:
/// DPR 1.0 (permukaan uji 1920×1080 logis) dan DPR 2.0 (kondisi TV
/// sebenarnya). Keduanya tidak boleh melempar exception overflow.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
import 'package:nekios_school/theme/theme.dart';
import 'package:nekios_school/ui/ui.dart';

JadwalData _muatDataAsli() => JadwalData.fromJson(
      jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
          as Map<String, dynamic>,
    );

DisplayStore _storePada(DateTime now) {
  final store = DisplayStore();
  store.terima(ScheduleReplaced(_muatDataAsli()));
  store.tick(now);
  return store;
}

/// Atur permukaan uji: 1920×1080 fisik pada rasio piksel [dpr].
void _aturPermukaan(WidgetTester tester, double dpr) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

Future<void> _pumpLayar(WidgetTester tester, DisplayStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: DisplayScreen(store: store),
    ),
  );
  await tester.pump();
}

void main() {
  group('Regresi overflow 1920×1080 — Selasa 09:20:24 (Pelajaran)', () {
    for (final dpr in [1.0, 2.0]) {
      testWidgets('DPR $dpr: tidak ada exception overflow', (tester) async {
        _aturPermukaan(tester, dpr);
        final store = _storePada(DateTime(2026, 11, 17, 9, 20, 24));
        addTearDown(store.dispose);

        await _pumpLayar(tester, store);
        expect(tester.takeException(), isNull);

        // Konten kunci tampil utuh.
        expect(find.text('SMKN 1 UKUI'), findsOneWidget);
        expect(find.text('24:36'), findsOneWidget);
        expect(find.text('Bahasa Indonesia'), findsOneWidget);
        // Subjudul header versi ringkas (tidak lagi terpotong).
        expect(
          find.text('Semester Ganjil 2026/2027 • Jurusan TKJ'),
          findsOneWidget,
        );
        // Strip: teks tengah ringkas, tidak menabrak countdown.
        expect(find.text('Jam ke-3 • Pelajaran berlangsung'), findsOneWidget);
        // Paging adaptif (ADR-010): halaman 1 berisi 4 kartu.
        expect(find.byType(KartuKelasSekarang), findsNWidgets(4));

        // Rotasi ke halaman 2 (sisa 2 kartu) pun tidak boleh
        // overflow.
        await tester.pump(const Duration(seconds: 12));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        expect(find.text('Bahasa Inggris'), findsOneWidget);
        expect(find.byType(KartuKelasSekarang), findsNWidgets(2));
      });
    }

    testWidgets('DPR 2.0: ISOMA juga tidak overflow', (tester) async {
      _aturPermukaan(tester, 2.0);
      final store = _storePada(DateTime(2026, 11, 17, 12, 20, 24));
      addTearDown(store.dispose);

      await _pumpLayar(tester, store);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('ISOMA'), findsWidgets);
      // Layout hero tanpa strip (ADR-008): countdown hanya di hero.
      expect(find.byType(StripStatusBel), findsNothing);
      expect(find.text('24:36'), findsOneWidget);
    });
  });
}
