/// Tes GaleriKegiatan (build pameran): mesin pola waktu tampil
/// (murni) + perilaku widget (tersembunyi di luar jendela tampil,
/// muncul dengan keterangan + foto di dalam jendela, hilang lagi
/// saat siklus berganti).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/ui/galeri_kegiatan.dart';

void main() {
  group('pola waktu galeri', () {
    test('tersembunyi selama 45 detik pertama tiap siklus', () {
      for (final detik in [0, 1, 30, 44, 90, 120, 134, 180]) {
        expect(
          GaleriKegiatan.tampilPada(detik),
          isFalse,
          reason: 'detik $detik harus tersembunyi',
        );
      }
    });

    test('tampil pada detik 45–89 tiap siklus', () {
      for (final detik in [45, 60, 89, 135, 179, 225]) {
        expect(
          GaleriKegiatan.tampilPada(detik),
          isTrue,
          reason: 'detik $detik harus tampil',
        );
      }
    });

    test('foto berganti tiap 9 detik dan berputar 10 foto', () {
      expect(GaleriKegiatan.indeksFotoPada(0), 0);
      expect(GaleriKegiatan.indeksFotoPada(8), 0);
      expect(GaleriKegiatan.indeksFotoPada(9), 1);
      expect(GaleriKegiatan.indeksFotoPada(45), 5);
      expect(GaleriKegiatan.indeksFotoPada(89), 9);
      expect(GaleriKegiatan.indeksFotoPada(90), 0);
      expect(GaleriKegiatan.indeksFotoPada(99), 1);
    });

    test('daftar foto berisi 10 aset galeri', () {
      expect(daftarFotoGaleriPameran, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(
          daftarFotoGaleriPameran[i],
          'assets/galeri/foto-${(i + 1).toString().padLeft(2, '0')}.jpg',
        );
      }
    });
  });

  group('widget GaleriKegiatan', () {
    testWidgets('tersembunyi di awal, tampil di jendela galeri, '
        'lalu tersembunyi lagi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GaleriKegiatan())),
      );
      await tester.pump();

      // Awal siklus: tidak ada foto, tidak ada keterangan.
      expect(find.byType(Image), findsNothing);
      expect(find.text('Galeri Kegiatan Sekolah'), findsNothing);

      // Masuk jendela tampil (detik 45).
      await tester.pump(const Duration(seconds: 45));
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Galeri Kegiatan Sekolah'), findsOneWidget);
      expect(find.text('SMKN 1 Ukui'), findsOneWidget);

      // Masih tampil menjelang akhir jendela (detik 89).
      await tester.pump(const Duration(seconds: 44));
      expect(find.text('Galeri Kegiatan Sekolah'), findsOneWidget);

      // Siklus baru (detik 90): galeri hilang lagi.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Galeri Kegiatan Sekolah'), findsNothing);

      // Buang widget agar timer berkala dibatalkan.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
