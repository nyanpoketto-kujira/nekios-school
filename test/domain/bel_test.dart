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
}
