import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
import 'package:nekios_school/theme/theme.dart';
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
  group('RunningTextMading (ADR-006)', () {
    testWidgets('widget langsung: badge MADING + teks tampil', (tester) async {
      aturLayarTv(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                Spacer(),
                RunningTextMading(teks: 'Halo mading sekolah'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('MADING'), findsOneWidget);
      expect(find.text('Halo mading sekolah'), findsOneWidget);
    });

    testWidgets('di DisplayScreen: mading kosong → teks sambutan default', (
      tester,
    ) async {
      aturLayarTv(tester);
      final store = storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: DisplayScreen(store: store),
        ),
      );
      await tester.pump();

      expect(find.text('MADING'), findsOneWidget);
      expect(
        find.textContaining('Selamat datang di SMKN 1 UKUI'),
        findsOneWidget,
      );
    });

    testWidgets('indikator remote: tampil hanya saat remoteTerhubung '
        '(Fase R1)', (tester) async {
      aturLayarTv(tester);
      Widget bar(bool terhubung) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              RunningTextMading(
                teks: 'Halo mading sekolah',
                remoteTerhubung: terhubung,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(bar(false));
      await tester.pump();
      expect(find.text('Remote terhubung'), findsNothing);
      expect(find.byKey(const Key('indikator-remote')), findsNothing);

      await tester.pumpWidget(bar(true));
      await tester.pump();
      expect(find.text('Remote terhubung'), findsOneWidget);
      expect(find.byKey(const Key('indikator-remote')), findsOneWidget);
    });

    testWidgets('di DisplayScreen: indikator mengikuti '
        'RemoteConnectionChanged di store', (tester) async {
      aturLayarTv(tester);
      final store = storePada(DateTime(2026, 11, 17, 9, 20, 24));
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: DisplayScreen(store: store),
        ),
      );
      await tester.pump();
      expect(find.text('Remote terhubung'), findsNothing);

      store.terima(const RemoteConnectionChanged(true));
      await tester.pump();
      expect(find.text('Remote terhubung'), findsOneWidget);

      store.terima(const RemoteConnectionChanged(false));
      await tester.pump();
      expect(find.text('Remote terhubung'), findsNothing);
    });

    testWidgets(
      'teks mading dari store tampil, dan berubah via MadingChanged',
      (tester) async {
        aturLayarTv(tester);
        final store = storePada(DateTime(2026, 11, 17, 9, 20, 24));
        addTearDown(store.dispose);
        store.terima(const MadingChanged('Pengumuman: upacara dimulai 07.15'));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: DisplayScreen(store: store),
          ),
        );
        await tester.pump();

        expect(find.text('Pengumuman: upacara dimulai 07.15'), findsOneWidget);
        expect(find.textContaining('Selamat datang'), findsNothing);

        // Event baru mengganti teks bar tanpa restart layar.
        store.terima(
          const MadingChanged('Info: perpustakaan buka sampai 16.00'),
        );
        await tester.pump();
        expect(
          find.text('Info: perpustakaan buka sampai 16.00'),
          findsOneWidget,
        );
        expect(find.text('Pengumuman: upacara dimulai 07.15'), findsNothing);
      },
    );
  });
}
