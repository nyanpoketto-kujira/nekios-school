import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';
import 'package:nekios_school/theme/theme.dart';
import 'package:nekios_school/ui/ui.dart';

/// Data uji: [jumlahKelas] kelas, satu slot pelajaran Senin
/// 07.00–07.45 berisi entri untuk semua kelas.
JadwalData dataUji(
  int jumlahKelas, {
  String kodeMapel = 'DDBP',
  String namaMapel = 'Dasar-Dasar Pemrograman',
}) {
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
    mapel: [
      Mapel(kode: kodeMapel, namaPanjang: namaMapel, warna: '#1'),
    ],
    hari: [
      HariJadwal(
        nama: 'senin',
        slots: [
          Slot(
            mulai: '07.00',
            selesai: '07.45',
            tipe: SlotTipe.pelajaran,
            entri: {
              for (final k in kelas) k.id: Entri(mapel: kodeMapel, kg: 1),
            },
          ),
        ],
      ),
    ],
  );
}

DateTime senin(int jam, int menit, [int detik = 0]) =>
    DateTime(2026, 11, 16, jam, menit, detik);

/// Font uji bawaan flutter_test jauh lebih lebar daripada Roboto
/// asli, jadi pemeriksaan "teks muat 2 baris" hanya bermakna bila
/// Roboto asli (dari cache font material SDK Flutter) berhasil
/// dimuat. Terverifikasi terpisah: dengan Roboto asli, nama PJOK
/// (44 karakter) muat 2 baris bahkan pada lebar isi kartu 300px.
bool _robotoAsliDimuat = false;

Future<bool> _muatRobotoAsli() async {
  final kandidat = <String>[];
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null) {
    kandidat.add('$envRoot/bin/cache/artifacts/material_fonts');
  }
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    kandidat.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final k in kandidat) {
    if (!File('$k/Roboto-Regular.ttf').existsSync()) continue;
    final loader = FontLoader('Roboto');
    for (final w in ['Regular', 'Medium', 'Bold']) {
      final f = File('$k/Roboto-$w.ttf');
      if (f.existsSync()) {
        final b = f.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(b.buffer)));
      }
    }
    await loader.load();
    return true;
  }
  return false;
}

/// Penjaga pemotongan senyap: teks yang melampaui maxLines tidak
/// memicu exception — periksa RenderParagraph satu per satu. Hanya
/// dijalankan bila Roboto asli termuat (lihat [_robotoAsliDimuat]).
void _pastikanTidakTerpotong(WidgetTester tester, String teks) {
  if (!_robotoAsliDimuat) return;
  for (final e in find.text(teks).evaluate()) {
    final rp = e.renderObject! as RenderParagraph;
    expect(rp.didExceedMaxLines, isFalse);
  }
}

void main() {
  setUpAll(() async {
    _robotoAsliDimuat = await _muatRobotoAsli();
  });
  group('kolomSpotlight (murni)', () {
    test('grid selalu 3 kolom (layout 3x3, muat 9 sekaligus)', () {
      expect(kolomSpotlight(1), 1);
      expect(kolomSpotlight(2), 2);
      expect(kolomSpotlight(3), 3);
      expect(kolomSpotlight(4), 3);
      expect(kolomSpotlight(6), 3);
      expect(kolomSpotlight(9), 3);
    });
  });

  group('halamanSpotlight (murni)', () {
    test('9 kelas ke bawah selalu 1 halaman', () {
      expect(halamanSpotlight(6, 0), 0);
      expect(halamanSpotlight(9, 59), 0);
    });

    test('10 kelas: 2 halaman x 30 detik', () {
      expect(halamanSpotlight(10, 0), 0);
      expect(halamanSpotlight(10, 29), 0);
      expect(halamanSpotlight(10, 30), 1);
      expect(halamanSpotlight(10, 59), 1);
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
      int jumlahKelas, {
      String kodeMapel = 'DDBP',
      String namaMapel = 'Dasar-Dasar Pemrograman',
      double skala = 1,
    }) async {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(
        ScheduleReplaced(
          dataUji(jumlahKelas, kodeMapel: kodeMapel, namaMapel: namaMapel),
        ),
      );
      store.tick(senin(6, 59));
      store.tick(senin(7, 0)); // masuk jam ke-1 -> spotlight mulai
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SkalaTampilan(
            skala: skala,
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

    testWidgets('6 kelas: semua kartu tampil di 1 halaman, tersusun '
        '3 kolom x 2 baris (grid 3x3)', (tester) async {
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
      // Geometri 3 kolom x 2 baris: Kelas 1-2-3 sebaris, Kelas 4
      // membuka baris kedua tepat di bawah Kelas 1.
      final p1 = tester.getTopLeft(find.text('Kelas 1'));
      final p2 = tester.getTopLeft(find.text('Kelas 2'));
      final p3 = tester.getTopLeft(find.text('Kelas 3'));
      final p4 = tester.getTopLeft(find.text('Kelas 4'));
      expect(p2.dy, p1.dy);
      expect(p3.dy, p1.dy);
      expect(p2.dx, greaterThan(p1.dx));
      expect(p3.dx, greaterThan(p2.dx));
      expect(p4.dy, greaterThan(p1.dy));
      expect(p4.dx, p1.dx);
    });

    testWidgets('13 kelas: halaman 1 berisi 9 kartu, halaman 2 sisanya, '
        'lalu hilang setelah 60 detik', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await siapkan(tester, 13);
      expect(find.text('Kelas 9'), findsOneWidget);
      expect(find.text('Kelas 10'), findsNothing);
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

    testWidgets(
        'nama mapel terpanjang (PJOK) tampil utuh tanpa overflow '
        'di kartu fullscreen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await siapkan(
        tester,
        6,
        kodeMapel: 'PJOK',
        namaMapel: 'Pendidikan Jasmani, Olahraga, dan Kesehatan',
      );
      // Teks penuh ada di setiap kartu (membungkus 2 baris, tidak
      // terpotong ellipsis) dan tidak ada pengecualian overflow.
      expect(
        find.text('Pendidikan Jasmani, Olahraga, dan Kesehatan'),
        findsNWidgets(6),
      );
      expect(tester.takeException(), isNull);
      _pastikanTidakTerpotong(
          tester, 'Pendidikan Jasmani, Olahraga, dan Kesehatan');
    });

    testWidgets(
        'PJOK juga utuh di jendela pendek (1280x620, skala aplikasi '
        '0.574 seperti rig Xvfb) — lebar kartu tidak ikut menyusut',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await siapkan(
        tester,
        6,
        kodeMapel: 'PJOK',
        namaMapel: 'Pendidikan Jasmani, Olahraga, dan Kesehatan',
        skala: 0.574,
      );
      expect(
        find.text('Pendidikan Jasmani, Olahraga, dan Kesehatan'),
        findsNWidgets(6),
      );
      expect(tester.takeException(), isNull);
      _pastikanTidakTerpotong(
          tester, 'Pendidikan Jasmani, Olahraga, dan Kesehatan');
    });
  });
}
