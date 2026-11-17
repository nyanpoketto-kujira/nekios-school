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

      // Kartu halaman 1 (paging 4-per-halaman, ADR-010):
      // X TKJ A, X TKJ B, XI TKJ A, XI TKJ B.
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsOneWidget);
      expect(find.text('Dasar-Dasar Program Keahlian'), findsOneWidget);
      expect(find.text('Bahasa Indonesia'), findsOneWidget);
      expect(find.text('Konsentrasi Keahlian TKJ'), findsOneWidget);
      expect(find.text('Bahasa Inggris'), findsNothing);
      expect(find.text('XII TKJ A'), findsNothing);

      // Rotasi 12 detik → halaman 2 = sisa 2 kelas (XII TKJ A,
      // XII TKJ B). Pump harus melewati durasi cascade 1200ms
      // (ADR-011) agar halaman lama benar-benar sudah pergi.
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('Bahasa Inggris'), findsOneWidget);
      expect(find.text('Konsentrasi Keahlian TKJ'), findsOneWidget);
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsNothing);
    });

    testWidgets(
        'paging adaptif: halaman 1 isi 4 kartu sama lebar; halaman 2 '
        'isi 2 kartu sama lebar & memenuhi baris (ADR-010)',
        (tester) async {
      aturLayarTv(tester);
      final store = storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Area konten pada 1920×1080 @ DPR 1.0 (skala tampilan 1.0):
      // lebar layar − padding layar 40×2; celah antar kartu 24.
      const lebarKonten = 1920.0 - 80.0;
      const celah = 24.0;

      List<double> lebarKartu() {
        final finder = find.byType(KartuKelasSekarang);
        return [
          for (var i = 0; i < tester.widgetList(finder).length; i++)
            tester.getSize(finder.at(i)).width,
        ];
      }

      void cekMerata(List<double> lebar, int jumlah) {
        expect(lebar.length, jumlah);
        for (final w in lebar) {
          expect(w, closeTo(lebar.first, 0.5),
              reason: 'semua kartu harus sama lebar');
        }
        // Total lebar kartu + celah di antaranya = lebar konten:
        // baris terisi penuh, tidak ada sisa ruang kosong di kanan.
        final total = lebar.fold(0.0, (a, b) => a + b) + celah * (jumlah - 1);
        expect(total, closeTo(lebarKonten, 1.0));
      }

      // Halaman 1: 4 kartu merata.
      cekMerata(lebarKartu(), 4);

      // Halaman 2: sisa 2 kartu — keduanya melebar merata memenuhi
      // baris (bukan menyusut ke lebar 4-kolom).
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      cekMerata(lebarKartu(), 2);
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
