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
        'rotasi 4→4: tengah transisi semua kartu lama & baru hadir, '
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
      expect(find.text('Informatika'), findsOneWidget);

      // Picu rotasi 12 detik, lalu berhenti di awal transisi
      // (250ms dari 1200ms ≈ progres 0,21): jendela indeks 0
      // (mulai 0 untuk n=4) sedang berjalan, jendela indeks
      // terakhir belum mulai (mulai 0,72).
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 250));

      // Koeksistensi PENUH: keempat kartu halaman lama dan
      // keempat kartu halaman baru sama-sama di tree — tidak ada
      // kartu yang hilang seketika seperti pola per-slot dulu.
      for (final nama in [
        'X TKR',
        'XI TKR',
        'XII TKR',
        'X TSM',
        'XI TSM',
        'XII TSM',
        'X TKJ A',
        'X TKJ B',
      ]) {
        expect(find.text(nama), findsWidgets, reason: nama);
      }
      // Chip timeline pun koeksis: chip lama & baru hadir bersama.
      expect(find.text('Bu Meizialisa'), findsWidgets);
      expect(find.text('Bu Erni'), findsWidgets);

      // Sifat SEKUENSIAL terukur dari opasitas elemen:
      // - indeks 0 kedua halaman sedang bertukar (0 < t < 1);
      expect(_opasitasElemen(tester, find.text('X TKR').first),
          allOf(greaterThan(0.0), lessThan(1.0)));
      expect(_opasitasElemen(tester, find.text('XI TSM').first),
          allOf(greaterThan(0.0), lessThan(1.0)));
      // - indeks terakhir halaman lama masih UTUH (belum keluar);
      expect(_opasitasElemen(tester, find.text('X TSM').first),
          closeTo(1.0, 0.001));
      expect(_opasitasElemen(tester, find.text('Bu Meizialisa').first),
          closeTo(1.0, 0.001));
      // - indeks terakhir halaman baru BELUM muncul.
      expect(_opasitasElemen(tester, find.text('X TKJ B').first),
          closeTo(0.0, 0.001));
      expect(_opasitasElemen(tester, find.text('Pak Yusuf').first),
          closeTo(0.0, 0.001));

      // Selesaikan transisi (total ≥1200ms): hanya halaman 2.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(KartuKelasSekarang), findsNWidgets(4));
      expect(find.text('Matematika'), findsOneWidget);
      expect(find.text('Informatika'), findsNothing);
      expect(find.text('Bu Meizialisa'), findsNothing);
    });

    testWidgets(
        'timeline: cascade per kolom sinkron antar baris & kepala kolom, '
        'chip benar-benar meluncur (addendum ADR-011)', (tester) async {
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

      final timeline = find.byType(TimelineJendela);
      expect(timeline, findsOneWidget);
      Finder diTimeline(String teks) =>
          find.descendant(of: timeline, matching: find.text(teks));

      // Posisi diam chip kolom 0 baris aktif (X TKR, 09.00)
      // sebelum rotasi — pembanding gerak meluncur nanti.
      final dyTriaDiam = tester.getTopLeft(diTimeline('Tria').first).dy;

      // Picu rotasi, berhenti di 250ms (progres ±0,21) — titik
      // yang sama dengan test kartu di atas. Singgah dulu di
      // 90ms untuk mengukur chip masuk kolom 0: jendela indeks 0
      // (n=4) pendek (±340ms), jadi di 250ms luncurannya hampir
      // selesai dan sisa jaraknya tak terukur.
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 90));
      final dyErniTengah =
          tester.getTopLeft(diTimeline('Bu Erni').first).dy;
      await tester.pump(const Duration(milliseconds: 160));

      // KOLOM TERAKHIR LAMA (indeks 3 dari 4, jendela mulai 0,72):
      // belum bergerak DI MANA PUN — kepala kolom utuh, dan chip
      // kolom itu di baris pertama maupun terakhir sama-sama
      // utuh. Bila satu baris saja mulai lebih dulu (switcher
      // per baris tidak sinkron), salah satu angka ini < 1.
      expect(_opasitasElemen(tester, diTimeline('X TSM')),
          closeTo(1.0, 0.001));
      expect(_opasitasElemen(tester, diTimeline('Bu Meizialisa').first),
          closeTo(1.0, 0.001));
      expect(_opasitasElemen(tester, diTimeline('Bu Meizialisa').last),
          closeTo(1.0, 0.001));

      // KOLOM TERAKHIR BARU (indeks 3 dari 4, jendela mulai
      // 0,72): belum muncul di baris mana pun.
      expect(_opasitasElemen(tester, diTimeline('Pak Yusuf').first),
          closeTo(0.0, 0.001));
      expect(_opasitasElemen(tester, diTimeline('Pak Yusuf').last),
          closeTo(0.0, 0.001));

      // KOLOM 0 SEDANG BERTUKAR di semua lapis timeline, dengan
      // opasitas yang SAMA antara kepala kolom dan chip baris
      // aktif: jendela cascade & momen mulai mereka satu —
      // sinkron dengan kartu ke-0 (test sebelumnya).
      final opasKepala0 = _opasitasElemen(tester, diTimeline('X TKR'));
      final opasChip0 = _opasitasElemen(tester, diTimeline('Tria').first);
      expect(opasKepala0, allOf(greaterThan(0.0), lessThan(1.0)));
      expect(opasChip0, closeTo(opasKepala0, 0.02));

      // GERAK MELUNCUR terukur dari posisi render, bukan cuma
      // fade: chip keluar kolom 0 sudah tenggelam jauh dari
      // posisi diamnya (geser desain 30 satuan), dan chip masuk
      // kolom 0 (XI TSM baris aktif 09.00) masih di bawah posisi
      // akhirnya — ia naik meluncur ke tempatnya.
      expect(tester.getTopLeft(diTimeline('Tria').first).dy,
          greaterThan(dyTriaDiam + 10));

      // Selesaikan transisi: chip masuk tepat di posisi akhir.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(diTimeline('Bu Erni').first).dy,
          lessThan(dyErniTengah - 2));
      expect(diTimeline('Bu Meizialisa'), findsNothing);
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
