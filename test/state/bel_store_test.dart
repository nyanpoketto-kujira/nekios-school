import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';

/// Jadwal uji ringkas hari Senin (2026-11-16):
/// 07.00–07.45 jam 1 • 07.45–08.30 jam 2 • 08.30–08.45 istirahat •
/// 08.45–09.30 jam 3 • 09.30–09.45 khusus ROHIS • 09.45–10.30 upacara •
/// 10.30–11.15 jam 4 • sesudahnya pulang.
JadwalData dataUji() {
  const entri = {'K1': Entri(mapel: 'DDBP', kg: 1)};
  return JadwalData(
    sekolah: 'SMK Uji',
    judul: 'Jadwal Uji',
    tahunPelajaran: '2026-2027',
    jurusan: 'TKJ',
    kelas: const [Kelas(id: 'K1', nama: 'X TKJ A', urutan: 1)],
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
            entri: entri,
          ),
          Slot(
            mulai: '07.45',
            selesai: '08.30',
            tipe: SlotTipe.pelajaran,
            entri: entri,
          ),
          Slot(mulai: '08.30', selesai: '08.45', tipe: SlotTipe.istirahat),
          Slot(
            mulai: '08.45',
            selesai: '09.30',
            tipe: SlotTipe.pelajaran,
            entri: entri,
          ),
          Slot(
            mulai: '09.30',
            selesai: '09.45',
            tipe: SlotTipe.khusus,
            label: 'ROHIS/ROKRIS',
          ),
          Slot(mulai: '09.45', selesai: '10.30', tipe: SlotTipe.upacara),
          Slot(
            mulai: '10.30',
            selesai: '11.15',
            tipe: SlotTipe.pelajaran,
            entri: entri,
          ),
        ],
      ),
    ],
  );
}

DateTime senin(int jam, int menit, [int detik = 0]) =>
    DateTime(2026, 11, 16, jam, menit, detik);

/// Rig store bel: kumpulkan semua rangkaian putar dari streamBel.
class RigBel {
  RigBel({bool belAktif = true, void Function(bool)? simpan})
    : store = DisplayStore(belAktifAwal: belAktif, simpanBelAktif: simpan) {
    _langganan = store.streamBel.listen(bunyi.add);
  }

  final DisplayStore store;
  final List<List<String>> bunyi = [];
  late final StreamSubscription<List<String>> _langganan;

  Future<void> muat(DateTime now) async {
    store.terima(ScheduleReplaced(dataUji()));
    store.tick(now);
    await pumpEventQueue();
  }

  Future<void> tick(DateTime now) async {
    store.tick(now);
    await pumpEventQueue();
  }

  Future<void> terima(DisplayEvent event) async {
    store.terima(event);
    await pumpEventQueue();
  }

  Future<void> tutup() async {
    await _langganan.cancel();
    store.dispose();
  }
}

// Rangkaian chunk yang diharapkan (pola ADR-017 revisi chunking).
List<String> rkJam(int n) => [
  'audio/cnk_chime_awal.mp3',
  'audio/cnk_info_jam.mp3',
  'audio/cnk_angka_$n.mp3',
  'audio/cnk_chime_akhir.mp3',
];
const rkIstirahat = [
  'audio/cnk_chime_awal.mp3',
  'audio/cnk_info_istirahat.mp3',
  'audio/cnk_chime_akhir.mp3',
];
const rkRohis = [
  'audio/cnk_chime_awal.mp3',
  'audio/cnk_info_rohis.mp3',
  'audio/cnk_chime_akhir.mp3',
];
const rkUpacara = [
  'audio/cnk_chime_awal.mp3',
  'audio/cnk_info_upacara.mp3',
  'audio/cnk_chime_akhir.mp3',
];
const rkPulang = [
  'audio/cnk_chime_awal.mp3',
  'audio/cnk_info_pulang.mp3',
  'audio/cnk_chime_akhir.mp3',
];

void main() {
  group('DisplayStore bel (ADR-017)', () {
    test('masuk jam ke-1: bel jam 1 + spotlight terisi', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      expect(rig.bunyi, isEmpty);

      await rig.tick(senin(7, 0));
      expect(rig.bunyi, [rkJam(1)]);
      expect(rig.store.belTerakhir?.berkas, 'audio/bel_jam_1.mp3');
      expect(rig.store.spotlight?.jamKe, 1);
    });

    test('tick berurutan di slot sama tidak membunyikan ulang', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      await rig.tick(senin(7, 0));
      await rig.tick(senin(7, 1));
      await rig.tick(senin(7, 44));
      expect(rig.bunyi, hasLength(1));
    });

    test('rangkaian transisi sehari: jam, istirahat, rohis, upacara, '
        'pulang', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      await rig.tick(senin(7, 0)); // jam 1
      await rig.tick(senin(7, 45)); // jam 2
      await rig.tick(senin(8, 30)); // istirahat
      expect(rig.store.spotlight, isNull);
      await rig.tick(senin(8, 45)); // jam 3
      expect(rig.store.spotlight?.jamKe, 3);
      await rig.tick(senin(9, 30)); // ROHIS
      await rig.tick(senin(9, 45)); // upacara
      await rig.tick(senin(10, 30)); // jam 4
      await rig.tick(senin(11, 15)); // pulang
      await rig.tick(senin(11, 16)); // tidak mengulang
      expect(rig.bunyi, [
        rkJam(1),
        rkJam(2),
        rkIstirahat,
        rkJam(3),
        rkRohis,
        rkUpacara,
        rkJam(4),
        rkPulang,
      ]);
    });

    test('belAktif nonaktif: diam, belTerakhir kosong, spotlight tetap '
        'tampil', () async {
      final rig = RigBel(belAktif: false);
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      await rig.tick(senin(7, 0));
      expect(rig.bunyi, isEmpty);
      expect(rig.store.belTerakhir, isNull);
      expect(rig.store.spotlight?.jamKe, 1);
    });

    test('BelKonfigurasiChanged mematikan bel + memanggil penyimpan',
        () async {
      final tersimpan = <bool>[];
      final rig = RigBel(simpan: tersimpan.add);
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      await rig.terima(const BelKonfigurasiChanged(false));
      expect(rig.store.belAktif, isFalse);
      expect(tersimpan, [false]);
      await rig.tick(senin(7, 0));
      expect(rig.bunyi, isEmpty);
    });

    test('TesBelDiminta tetap berbunyi walau bel nonaktif', () async {
      final rig = RigBel(belAktif: false);
      addTearDown(rig.tutup);
      await rig.muat(senin(7, 10)); // sudah di dalam jam ke-1
      await rig.terima(const TesBelDiminta());
      expect(rig.bunyi, [rkJam(1)]);
    });

    test('TesBelDiminta di luar jam slot memutar contoh jam ke-1', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 30)); // sebelum masuk
      await rig.terima(const TesBelDiminta());
      expect(rig.bunyi, [rkJam(1)]);
    });

    test('loncat simulasi ke slot lain MEMICU bel (jalur demo)', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(7, 10)); // jam ke-1 waktu nyata
      await rig.tick(senin(7, 10));
      rig.bunyi.clear();
      // Simulasi: geser +40 menit -> 07.50 (jam ke-2).
      await rig.terima(ClockSimulated(const Duration(minutes: 40)));
      // terima menghitung ulang dengan nowSistem terakhir (07.10) +
      // offset 40m = 07.50 -> transisi ke jam ke-2.
      expect(rig.bunyi, [rkJam(2)]);
    });

    test('ClockSimulationCleared MENELAN transisi kembali', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(7, 10));
      await rig.terima(ClockSimulated(const Duration(minutes: 40)));
      rig.bunyi.clear();
      await rig.terima(const ClockSimulationCleared());
      expect(rig.bunyi, isEmpty);
      expect(rig.store.simulasiAktif, isFalse);
    });

    test('ScheduleReplaced MENELAN lonjakan keadaan', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(7, 10)); // jam ke-1 (indeks 0)
      expect(rig.bunyi, isEmpty); // muat awal tidak berbunyi
      // Jadwal pengganti: pada 07.10 posisinya indeks 1.
      final v2 = dataUji();
      final pengganti = JadwalData(
        sekolah: v2.sekolah,
        judul: v2.judul,
        tahunPelajaran: v2.tahunPelajaran,
        jurusan: v2.jurusan,
        kelas: v2.kelas,
        guru: v2.guru,
        mapel: v2.mapel,
        hari: [
          HariJadwal(
            nama: 'senin',
            slots: [
              Slot(
                mulai: '06.30',
                selesai: '07.05',
                tipe: SlotTipe.pelajaran,
                entri: const {'K1': Entri(mapel: 'DDBP', kg: 1)},
              ),
              Slot(
                mulai: '07.05',
                selesai: '07.50',
                tipe: SlotTipe.pelajaran,
                entri: const {'K1': Entri(mapel: 'DDBP', kg: 1)},
              ),
            ],
          ),
        ],
      );
      await rig.terima(ScheduleReplaced(pengganti));
      expect(rig.bunyi, isEmpty);
    });

    test('snapshot memuat belAktif dan belTerakhir', () async {
      final rig = RigBel();
      addTearDown(rig.tutup);
      await rig.muat(senin(6, 59));
      var snap = rig.store.snapshotPaket();
      expect(snap['belAktif'], isTrue);
      expect(snap['belTerakhir'], isNull);
      await rig.tick(senin(7, 0));
      snap = rig.store.snapshotPaket();
      final terakhir = snap['belTerakhir'] as Map<String, dynamic>;
      expect(terakhir['berkas'], 'audio/bel_jam_1.mp3');
      expect(terakhir['pada'], senin(7, 0).toIso8601String());
    });
  });
}
