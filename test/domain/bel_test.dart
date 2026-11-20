import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';

void main() {
  group('berkasBelUntukSlot (ADR-017)', () {
    Slot slot(SlotTipe tipe, {String? label}) => Slot(
      mulai: '07.00',
      selesai: '07.45',
      tipe: tipe,
      label: label,
    );

    test('pelajaran memakai nomor jam ke', () {
      expect(
        berkasBelUntukSlot(slot(SlotTipe.pelajaran), 1),
        'audio/bel_jam_1.mp3',
      );
      expect(
        berkasBelUntukSlot(slot(SlotTipe.pelajaran), 10),
        'audio/bel_jam_10.mp3',
      );
    });

    test('pelajaran tanpa nomor jam tidak punya pengumuman', () {
      expect(berkasBelUntukSlot(slot(SlotTipe.pelajaran), null), isNull);
    });

    test('istirahat, isoma, upacara punya berkas tetap', () {
      expect(
        berkasBelUntukSlot(slot(SlotTipe.istirahat), null),
        'audio/bel_istirahat.mp3',
      );
      expect(
        berkasBelUntukSlot(slot(SlotTipe.isoma), null),
        'audio/bel_isoma.mp3',
      );
      expect(
        berkasBelUntukSlot(slot(SlotTipe.upacara), null),
        'audio/bel_upacara.mp3',
      );
    });

    test('khusus ROHIS/ROKRIS memakai bel rohis', () {
      expect(
        berkasBelUntukSlot(slot(SlotTipe.khusus, label: 'ROHIS/ROKRIS'), null),
        'audio/bel_rohis.mp3',
      );
      expect(
        berkasBelUntukSlot(slot(SlotTipe.khusus, label: 'Rohis'), null),
        'audio/bel_rohis.mp3',
      );
    });

    test('khusus lain memakai bel kegiatan generik', () {
      expect(
        berkasBelUntukSlot(
          slot(SlotTipe.khusus, label: 'Kokurikuler/Ekstrakurikuler'),
          null,
        ),
        'audio/bel_kegiatan.mp3',
      );
      expect(
        berkasBelUntukSlot(slot(SlotTipe.khusus), null),
        'audio/bel_kegiatan.mp3',
      );
    });

    test('konstanta pulang dan contoh tes', () {
      expect(kBerkasBelPulang, 'audio/bel_pulang.mp3');
      expect(kBerkasBelContoh, 'audio/bel_jam_1.mp3');
    });
  });

  group('rangkaianBelUntukSlot — chunk (ADR-017 revisi chunking)', () {
    Slot slot(SlotTipe tipe, {String? label}) => Slot(
      mulai: '07.00',
      selesai: '07.45',
      tipe: tipe,
      label: label,
    );

    test('pelajaran: chime awal + info jam + angka + chime akhir', () {
      expect(rangkaianBelUntukSlot(slot(SlotTipe.pelajaran), 1), [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_jam.mp3',
        'audio/cnk_angka_1.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
      expect(rangkaianBelUntukSlot(slot(SlotTipe.pelajaran), 10), [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_jam.mp3',
        'audio/cnk_angka_10.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
    });

    test('pelajaran tanpa nomor jam tidak punya rangkaian', () {
      expect(rangkaianBelUntukSlot(slot(SlotTipe.pelajaran), null), isNull);
    });

    test('istirahat, isoma, upacara: chime + info utuh + chime', () {
      expect(rangkaianBelUntukSlot(slot(SlotTipe.istirahat), null), [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_istirahat.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
      expect(rangkaianBelUntukSlot(slot(SlotTipe.isoma), null), [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_isoma.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
      expect(rangkaianBelUntukSlot(slot(SlotTipe.upacara), null), [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_upacara.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
    });

    test('khusus ROHIS memakai info rohis, lainnya info kegiatan', () {
      expect(
        rangkaianBelUntukSlot(
          slot(SlotTipe.khusus, label: 'ROHIS/ROKRIS'),
          null,
        ),
        [
          'audio/cnk_chime_awal.mp3',
          'audio/cnk_info_rohis.mp3',
          'audio/cnk_chime_akhir.mp3',
        ],
      );
      expect(
        rangkaianBelUntukSlot(
          slot(SlotTipe.khusus, label: 'Kokurikuler/Ekstrakurikuler'),
          null,
        ),
        [
          'audio/cnk_chime_awal.mp3',
          'audio/cnk_info_kegiatan.mp3',
          'audio/cnk_chime_akhir.mp3',
        ],
      );
    });

    test('rangkaian pulang dan contoh tes', () {
      expect(kRangkaianBelPulang, [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_pulang.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
      expect(kRangkaianBelContoh, [
        'audio/cnk_chime_awal.mp3',
        'audio/cnk_info_jam.mp3',
        'audio/cnk_angka_1.mp3',
        'audio/cnk_chime_akhir.mp3',
      ]);
    });

    test('cnkAngka memakai pola nama per nomor', () {
      expect(cnkAngka(3), 'audio/cnk_angka_3.mp3');
      expect(cnkAngka(12), 'audio/cnk_angka_12.mp3');
    });
  });
}
