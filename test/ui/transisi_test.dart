/// Test transisi cascade sekuensial M3 (ADR-011, mengamendemen
/// pola per-slot ADR-009).
///
/// - Rotasi halaman memakai switcher LEVEL-HALAMAN
///   (TransisiHalaman): seluruh isi wilayah ter-swap sebagai satu
///   kesatuan; tiap elemen beranimasi lewat ElemenHalaman dengan
///   jendela cascade per indeks dari animasi switcher yang sama.
/// - Cascade SEKUENSIAL, bukan stagger tumpang-tindih: di awal
///   transisi (250ms dari 1200ms) hanya indeks 0 yang sedang
///   bertukar — indeks terakhir halaman lama masih utuh
///   (opasitas 1) dan indeks terakhir halaman baru belum muncul
///   (opasitas 0).
/// - Pindah halaman 4→2: di tengah transisi KEEMPAT kartu lama
///   DAN kedua kartu baru sama-sama ada di tree (tidak ada elemen
///   yang hilang seketika); setelah selesai hanya halaman baru.
/// - Pergantian status Pelajaran → ISOMA melewati switcher
///   fade-through di level layar (600ms).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
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

/// Opasitas ElemenHalaman yang membungkus teks pada [teks]
/// (satu-satunya Opacity di rantai leluhur teks layar ini).
double _opasitasElemen(WidgetTester tester, Finder teks) {
  final leluhur = find.ancestor(of: teks, matching: find.byType(Opacity));
  expect(leluhur, findsOneWidget);
  return tester.widget<Opacity>(leluhur).opacity;
}

void main() {
  group('Jendela cascade (ADR-011)', () {
    test('rumus jendela: mulai 0, berakhir 1, overlap ±15%', () {
      for (final n in [2, 3, 4, 6]) {
        final jendela = [for (var i = 0; i < n; i++) jendelaCascade(i, n)];
        expect(jendela.first.begin, 0.0);
        expect(jendela.last.end, closeTo(1.0, 1e-9));
        for (var i = 0; i + 1 < n; i++) {
          final lebar = jendela[i].end - jendela[i].begin;
          final tumpang = jendela[i].end - jendela[i + 1].begin;
          // Tumpang tindih antar jendela berurutan maksimal ±15%
          // lebar jendela: gerak nyaris sekuensial.
          expect(tumpang / lebar, closeTo(0.15, 0.001),
              reason: 'n=$n indeks=$i');
        }
      }
    });

    test('n=1 jendela penuh; n=4 tiap elemen ±340ms dari 1200ms', () {
      final tunggal = jendelaCascade(0, 1);
      expect(tunggal.begin, 0.0);
      expect(tunggal.end, 1.0);
      final lebar4 = jendelaCascade(0, 4).end - jendelaCascade(0, 4).begin;
      expect(lebar4 * 1200, closeTo(338, 2));
    });
  });

  group('Transisi cascade sekuensial (ADR-011)', () {
    testWidgets(
        'rotasi 4→2: tengah transisi semua kartu lama & baru hadir, '
        'cascade berurutan dari indeks 0', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = _storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Pola baru terpasang: switcher level-halaman + elemen.
      expect(find.byType(TransisiHalaman), findsWidgets);
      expect(find.byType(ElemenHalaman), findsWidgets);
      expect(find.text('Bahasa Indonesia'), findsOneWidget);

      // Picu rotasi 12 detik, lalu berhenti di awal transisi
      // (250ms dari 1200ms ≈ progres 0,21): jendela indeks 0
      // (0–0,28 untuk n=4; 0–0,54 untuk n=2) sedang berjalan,
      // jendela indeks terakhir belum mulai (mulai 0,72 / 0,46).
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 250));

      // Koeksistensi PENUH: keempat kartu halaman lama dan kedua
      // kartu halaman baru sama-sama di tree — tidak ada kartu
      // yang hilang seketika seperti pola per-slot dulu.
      for (final nama in [
        'X TKJ A',
        'X TKJ B',
        'XI TKJ A',
        'XI TKJ B',
        'XII TKJ A',
        'XII TKJ B',
      ]) {
        expect(find.text(nama), findsWidgets, reason: nama);
      }
      // Chip timeline pun koeksis: chip lama & baru hadir bersama.
      expect(find.text('Bu Sumiati'), findsWidgets);
      expect(find.text('Pak Rudi'), findsWidgets);

      // Sifat SEKUENSIAL terukur dari opasitas elemen:
      // - indeks 0 kedua halaman sedang bertukar (0 < t < 1);
      expect(_opasitasElemen(tester, find.text('X TKJ A').first),
          allOf(greaterThan(0.0), lessThan(1.0)));
      expect(_opasitasElemen(tester, find.text('XII TKJ A').first),
          allOf(greaterThan(0.0), lessThan(1.0)));
      // - indeks terakhir halaman lama masih UTUH (belum keluar);
      expect(_opasitasElemen(tester, find.text('XI TKJ B').first),
          closeTo(1.0, 0.001));
      expect(_opasitasElemen(tester, find.text('Bu Sumiati').first),
          closeTo(1.0, 0.001));
      // - indeks terakhir halaman baru BELUM muncul.
      expect(_opasitasElemen(tester, find.text('XII TKJ B').first),
          closeTo(0.0, 0.001));
      expect(_opasitasElemen(tester, find.text('Pak Rudi').first),
          closeTo(0.0, 0.001));

      // Selesaikan transisi (total ≥1200ms): hanya halaman 2.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(KartuKelasSekarang), findsNWidgets(2));
      expect(find.text('Bahasa Inggris'), findsOneWidget);
      expect(find.text('Bahasa Indonesia'), findsNothing);
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsNothing);
      expect(find.text('Bu Sumiati'), findsNothing);
    });

    testWidgets('status: Pelajaran → ISOMA lewat fade-through layar',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = _storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DisplayScreen(store: store)),
      );
      await tester.pump();
      expect(find.byType(StripStatusBel), findsOneWidget);

      // Ganti waktu efektif ke ISOMA: status berubah, layout
      // berganti lewat AnimatedSwitcher fade-through (600ms).
      store.tick(DateTime(2026, 11, 17, 12, 20, 24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ISOMA'), findsOneWidget);
      expect(find.byType(StripStatusBel), findsNothing);
    });
  });
}
