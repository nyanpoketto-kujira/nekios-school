import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';

/// Test mesin jadwal memakai data asli + jam-jam skenario yang sama
/// dengan board desain Penpot (Varian J, Rotasi, dan board Status),
/// supaya angka countdown/progres di test = angka di desain.
/// Pekan acuan: Senin 2026-11-16 s.d. Sabtu 2026-11-21.
void main() {
  late JadwalData data;

  setUpAll(() {
    final berkas = File('assets/jadwal-tkj.json');
    data = JadwalData.fromJson(
      jsonDecode(berkas.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  group('skenario desain — Selasa 09:20 (Varian J / Rotasi 1)', () {
    late final KeadaanTampilan k;
    setUpAll(() {
      k = hitungKeadaan(data, DateTime(2026, 11, 17, 9, 20, 24));
    });

    test('status pelajaran, slot 09.00–09.45, Jam ke-3', () {
      expect(k.status, StatusSekolah.pelajaran);
      expect(k.slotAktif?.mulai, '09.00');
      expect(k.slotAktif?.selesai, '09.45');
      expect(k.indeksAktif, 2);
      expect(k.jamKeAktif, 3);
    });

    test('countdown bel 24:36 dan progres 1224/2700', () {
      expect(k.sisaKeBel, const Duration(minutes: 24, seconds: 36));
      expect(k.belBerikutnya, DateTime(2026, 11, 17, 9, 45));
      expect(k.progresSlot, closeTo(1224 / 2700, 0.001));
    });

    test('slot berikutnya 09.45 dan entri per kelas sesuai desain', () {
      expect(k.slotBerikutnya?.mulai, '09.45');
      final entri = k.slotAktif!.entri;
      expect(entri['X-TKJ-A']?.mapel, 'IPAS');
      expect(entri['XI-TKJ-A']?.mapel, 'B.IND');
      expect(entri['XII-TKJ-A']?.kg, 15);
    });

    test('jendela timeline: 2 selesai, aktif, berikutnya, istirahat', () {
      expect(k.jendela.length, 5);
      expect(
        k.jendela.map((b) => b.keadaan),
        [
          KeadaanSlot.selesai,
          KeadaanSlot.selesai,
          KeadaanSlot.aktif,
          KeadaanSlot.berikutnya,
          KeadaanSlot.akanDatang,
        ],
      );
      expect(k.jendela.last.slot.tipe, SlotTipe.istirahat);
      expect(k.jendela[2].jamKe, 3);
    });
  });

  group('skenario desain — status-status lain', () {
    test('Selasa 12:20 ISOMA: status isoma, countdown 24:36', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 12, 20, 24));
      expect(k.status, StatusSekolah.isoma);
      expect(k.slotAktif?.tipe, SlotTipe.isoma);
      expect(k.sisaKeBel, const Duration(minutes: 24, seconds: 36));
      expect(k.jamKeAktif, isNull);
    });

    test('Selasa 10:35 istirahat pendek', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 10, 35));
      expect(k.status, StatusSekolah.istirahat);
      expect(k.slotAktif?.selesai, '10.45');
    });

    test('Senin 07:30 upacara: status khusus, countdown 29:24', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 16, 7, 30, 36));
      expect(k.status, StatusSekolah.khusus);
      expect(k.slotAktif?.tipe, SlotTipe.upacara);
      expect(k.sisaKeBel, const Duration(minutes: 29, seconds: 24));
    });

    test('Jumat 07:40 ROHIS: status khusus, countdown 34:12', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 20, 7, 40, 48));
      expect(k.status, StatusSekolah.khusus);
      expect(k.slotAktif?.label, contains('ROHIS'));
      expect(k.sisaKeBel, const Duration(minutes: 34, seconds: 12));
    });

    test('Selasa 06:58 sebelum masuk: countdown ke bel 07.30 = 31:42', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 6, 58, 18));
      expect(k.status, StatusSekolah.sebelumMasuk);
      expect(k.slotAktif, isNull);
      expect(k.slotBerikutnya?.mulai, '07.30');
      expect(k.sisaKeBel, const Duration(minutes: 31, seconds: 42));
      expect(k.jendela.length, 5);
      expect(k.jendela.first.keadaan, KeadaanSlot.berikutnya);
      expect(
        k.jendela.skip(1).every((b) => b.keadaan == KeadaanSlot.akanDatang),
        isTrue,
      );
    });

    test('Selasa 15:50 pulang: besok Rabu, bel 07.30, jendela selesai', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 15, 50));
      expect(k.status, StatusSekolah.pulang);
      expect(k.hariBerikutnya?.nama, 'rabu');
      expect(k.belBerikutnya, DateTime(2026, 11, 18, 7, 30));
      expect(k.jendela.length, 5);
      expect(
        k.jendela.every((b) => b.keadaan == KeadaanSlot.selesai),
        isTrue,
      );
    });

    test('Jumat sore pulang: hari berikutnya Senin (lewati akhir pekan)', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 20, 16, 0));
      expect(k.status, StatusSekolah.pulang);
      expect(k.hariBerikutnya?.nama, 'senin');
      expect(k.belBerikutnya, DateTime(2026, 11, 23, 7, 15));
    });

    test('Sabtu: tidak ada jadwal, berikutnya Senin 07.15', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 21, 10, 0));
      expect(k.status, StatusSekolah.tidakAdaJadwal);
      expect(k.hariIni, isNull);
      expect(k.hariBerikutnya?.nama, 'senin');
      expect(k.belBerikutnya, DateTime(2026, 11, 23, 7, 15));
    });
  });

  group('batas slot', () {
    test('tepat 09.45: slot berikutnya yang aktif (Jam ke-4)', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 9, 45));
      expect(k.slotAktif?.mulai, '09.45');
      expect(k.jamKeAktif, 4);
      expect(k.progresSlot, 0.0);
    });

    test('tepat 07.30: sudah masuk, bukan sebelum masuk', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 7, 30));
      expect(k.status, StatusSekolah.pelajaran);
      expect(k.indeksAktif, 0);
    });

    test('tepat 15.45 (akhir slot terakhir): pulang', () {
      final k = hitungKeadaan(data, DateTime(2026, 11, 17, 15, 45));
      expect(k.status, StatusSekolah.pulang);
    });
  });

  group('jamKePada', () {
    test('menghitung hanya slot pelajaran', () {
      final selasa = data.hariByNama('selasa')!;
      expect(jamKePada(selasa, 0), 1);
      expect(jamKePada(selasa, 3), 4);
      expect(jamKePada(selasa, 4), isNull); // istirahat
      expect(jamKePada(selasa, 5), 5);
      expect(jamKePada(selasa, 7), isNull); // isoma
      expect(jamKePada(selasa, 11), 10);
    });

    test('Senin: upacara bukan jam ke, pelajaran pertama = Jam ke-1', () {
      final senin = data.hariByNama('senin')!;
      expect(jamKePada(senin, 0), isNull);
      expect(jamKePada(senin, 1), 1);
    });
  });

  group('halamanRotasi', () {
    test('ukuran halaman bawaan = 4 (ADR-010)', () {
      expect(ukuranHalamanRotasi, 4);
    });

    test('18 kelas semua jurusan menjadi 5 halaman isi [4, 4, 4, 4, 2]',
        () {
      final halaman = halamanRotasi(data.kelas);
      expect(halaman.length, 5);
      expect(
        halaman[0].map((k) => k.id),
        ['X-TKR', 'XI-TKR', 'XII-TKR', 'X-TSM'],
      );
      expect(
        halaman[4].map((k) => k.id),
        ['XI-TET', 'XII-TET'],
      );
    });

    test('mengurutkan berdasar urutan walau input acak', () {
      final acak = [...data.kelas.reversed];
      final halaman = halamanRotasi(acak, perHalaman: 18);
      expect(halaman.single.first.id, 'X-TKR');
      expect(halaman.single.last.id, 'XII-TET');
    });

    // Paging adaptif (ADR-010): jumlah kelas berapa pun harus
    // terbagi rapi — halaman terakhir berisi sisa (3, 2, atau 1)
    // tanpa halaman kosong. Kelas sintetis minimal cukup di level
    // fungsi paging; data aset tidak perlu diubah.
    group('adaptif terhadap jumlah kelas berapa pun', () {
      List<Kelas> sintetis(int n) => [
            for (var i = 1; i <= n; i++)
              Kelas(id: 'K$i', nama: 'Kelas $i', urutan: i),
          ];

      void cek(int total, List<int> isiHalaman) {
        final halaman = halamanRotasi(sintetis(total));
        expect(
          halaman.map((h) => h.length),
          isiHalaman,
          reason: '$total kelas → $isiHalaman',
        );
        // Tidak ada kelas hilang/duplikat dan urutan terjaga.
        expect(
          halaman.expand((h) => h).map((k) => k.urutan),
          [for (var i = 1; i <= total; i++) i],
        );
      }

      test('5 kelas → [4, 1]', () => cek(5, [4, 1]));
      test('8 kelas → [4, 4]', () => cek(8, [4, 4]));
      test('4 kelas → [4]', () => cek(4, [4]));
      test('1 kelas → [1]', () => cek(1, [1]));
      test('7 kelas → [4, 3]', () => cek(7, [4, 3]));
      test('0 kelas → tanpa halaman', () {
        expect(halamanRotasi(const <Kelas>[]), isEmpty);
      });
    });
  });
}
