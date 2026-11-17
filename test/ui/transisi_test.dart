/// Test transisi ekspresif M3 (ADR-009).
///
/// - Rotasi halaman memakai TransisiRotasi (SlideTransition +
///   ScaleTransition + FadeTransition per kartu/kolom), bukan
///   crossfade polos AnimatedSwitcher bawaan.
/// - Di tengah transisi rotasi, kartu lama & baru sama-sama ada di
///   tree pada slot yang persisten; setelah durasi selesai hanya
///   halaman baru. (Paging adaptif ADR-010: halaman bisa beda
///   panjang — slot ekstra di halaman yang lebih panjang dilepas
///   bersama barisnya, jadi koeksistensi diuji pada slot indeks 0.)
/// - Pergantian status Pelajaran → ISOMA melewati switcher
///   fade-through di level layar (ScaleTransition tingkat layar).
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

void main() {
  group('Transisi ekspresif M3 (ADR-009)', () {
    testWidgets(
        'rotasi: transisi geser+skala stagger terpasang, halaman '
        'berganti bersih', (tester) async {
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

      // Widget transisi baru terpasang di area rotasi.
      expect(find.byType(TransisiRotasi), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.text('Bahasa Indonesia'), findsOneWidget);

      // Picu rotasi 12 detik, lalu berhenti di tengah transisi
      // (100ms dari 500ms): pada slot persisten (indeks 0), kartu
      // lama (X TKJ A) & baru (XII TKJ A) sama-sama di tree.
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ilmu Pengetahuan Alam dan Sosial'), findsOneWidget);
      expect(find.text('Bahasa Inggris'), findsOneWidget);

      // Selesaikan transisi: hanya halaman 2 yang tersisa.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Bahasa Indonesia'), findsNothing);
      expect(find.text('Bahasa Inggris'), findsOneWidget);
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
      // berganti lewat AnimatedSwitcher fade-through (400ms).
      store.tick(DateTime(2026, 11, 17, 12, 20, 24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('ISOMA'), findsOneWidget);
      expect(find.byType(StripStatusBel), findsNothing);
    });
  });
}
