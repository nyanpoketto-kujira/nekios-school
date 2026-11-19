import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
import 'package:nekios_school/theme/theme.dart';
import 'package:nekios_school/ui/ui.dart';

/// Data uji: [jumlahKelas] kelas, satu slot pelajaran Senin
/// 07.00–07.45 berisi entri untuk semua kelas.
JadwalData dataUji(int jumlahKelas) {
  final kelas = [
    for (var i = 1; i <= jumlahKelas; i++)
      Kelas(id: 'K$i', nama: 'Kelas $i', urutan: i),
  ];
  return JadwalData(
    sekolah: 'SMK Uji',
    judul: 'Jadwal Uji',
    tahunPelajaran: '2026-2027',
    jurusan: 'TKJ',
    kelas: kelas,
    guru: const [Guru(kg: 1, nama: 'Rudi, S.T.', terverifikasi: true)],
    mapel: const [
      Mapel(kode: 'DDBP', namaPanjang: 'Dasar-Dasar Pemrograman', warna: '#1'),
    ],
    hari: [
      HariJadwal(
        nama: 'senin',
        slots: [
          Slot(
            mulai: '07.00',
            selesai: '07.45',
            tipe: SlotTipe.pelajaran,
            entri: {for (final k in kelas) k.id: const Entri(mapel: 'DDBP', kg: 1)},
          ),
        ],
      ),
    ],
  );
}

DateTime senin(int jam, int menit, [int detik = 0]) =>
    DateTime(2026, 11, 16, jam, menit, detik);

void main() {
  group('halamanSpotlight (murni)', () {
    test('12 kelas ke bawah selalu 1 halaman', () {
      expect(halamanSpotlight(6, 0), 0);
      expect(halamanSpotlight(12, 59), 0);
    });

    test('13 kelas: 2 halaman x 30 detik', () {
      expect(halamanSpotlight(13, 0), 0);
      expect(halamanSpotlight(13, 29), 0);
      expect(halamanSpotlight(13, 30), 1);
      expect(halamanSpotlight(13, 59), 1);
    });

    test('25 kelas: 3 halaman x 20 detik, halaman terakhir menahan', () {
      expect(halamanSpotlight(25, 0), 0);
      expect(halamanSpotlight(25, 20), 1);
      expect(halamanSpotlight(25, 40), 2);
      expect(halamanSpotlight(25, 59), 2);
    });
  });

  group('SpotlightPergantian (widget)', () {
    Future<DisplayStore> siapkan(
      WidgetTester tester,
      int jumlahKelas,
    ) async {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(ScheduleReplaced(dataUji(jumlahKelas)));
      store.tick(senin(6, 59));
      store.tick(senin(7, 0)); // masuk jam ke-1 -> spotlight mulai
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SkalaTampilan(
            skala: 1,
            child: Scaffold(
              // Sama seperti pemasangan di DisplayScreen: overlay
              // dibangun ulang mengikuti notifikasi store per detik.
              body: ListenableBuilder(
                listenable: store,
                builder: (context, _) => SpotlightPergantian(store: store),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return store;
    }

    testWidgets('6 kelas: semua kartu tampil di 1 halaman', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await siapkan(tester, 6);
      expect(find.text('Pergantian Jam'), findsOneWidget);
      expect(find.text('Jam Pelajaran ke-1 • 07.00–07.45'), findsOneWidget);
      for (var i = 1; i <= 6; i++) {
        expect(find.text('Kelas $i'), findsOneWidget);
      }
      expect(find.textContaining('Halaman'), findsNothing);
      expect(spotlightSedangTampil(store), isTrue);
    });

    testWidgets('13 kelas: halaman 1 berisi 12 kartu, halaman 2 sisanya, '
        'lalu hilang setelah 60 detik', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await siapkan(tester, 13);
      expect(find.text('Kelas 12'), findsOneWidget);
      expect(find.text('Kelas 13'), findsNothing);
      expect(find.text('Halaman 1 dari 2'), findsOneWidget);

      store.tick(senin(7, 0, 31)); // halaman ke-2 (30 detik/halaman)
      await tester.pump();
      expect(find.text('Kelas 13'), findsOneWidget);
      expect(find.text('Kelas 1'), findsNothing);
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);

      store.tick(senin(7, 1, 1)); // lewat 60 detik
      await tester.pump();
      expect(spotlightSedangTampil(store), isFalse);
      expect(find.text('Pergantian Jam'), findsNothing);
    });
  });
}
