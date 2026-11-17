import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/models.dart';

void main() {
  group('menitDariJam', () {
    test('mengubah JJ.MM ke menit sejak tengah malam', () {
      expect(menitDariJam('07.30'), 450);
      expect(menitDariJam('09.45'), 585);
      expect(menitDariJam('00.00'), 0);
    });

    test('format rusak melempar FormatException', () {
      expect(() => menitDariJam('07:30'), throwsFormatException);
    });
  });

  group('JadwalData round-trip JSON', () {
    test('parse → serialize → parse stabil (idempoten)', () {
      final mentah =
          jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
              as Map<String, dynamic>;
      final pertama = JadwalData.fromJson(mentah);
      final kedua = JadwalData.fromJson(pertama.toJson());
      expect(jsonEncode(kedua.toJson()), jsonEncode(pertama.toJson()));
    });

    test('lookup guru, mapel, dan hari bekerja', () {
      final mentah =
          jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
              as Map<String, dynamic>;
      final data = JadwalData.fromJson(mentah);
      expect(data.guruByKg(7)?.nama, contains('Eva'));
      expect(data.mapelByKode('IPAS')?.namaPanjang,
          'Ilmu Pengetahuan Alam dan Sosial');
      expect(data.hariByNama('selasa')?.slots.length, 12);
      expect(data.guruByKg(999), isNull);
    });

    test('slot Selasa 09.00 berisi entri yang benar', () {
      final mentah =
          jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
              as Map<String, dynamic>;
      final data = JadwalData.fromJson(mentah);
      final slot = data
          .hariByNama('selasa')!
          .slots
          .firstWhere((s) => s.mulai == '09.00');
      expect(slot.tipe, SlotTipe.pelajaran);
      expect(slot.entri['X-TKJ-A']?.mapel, 'IPAS');
      expect(slot.entri['XII-TKJ-B']?.kg, 6);
      expect(slot.durasiMenit, 45);
    });

    test('slot upacara Senin terbaca sebagai tipe upacara berlabel', () {
      final mentah =
          jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
              as Map<String, dynamic>;
      final data = JadwalData.fromJson(mentah);
      final slot = data.hariByNama('senin')!.slots.first;
      expect(slot.tipe, SlotTipe.upacara);
      expect(slot.label, isNotNull);
      expect(slot.entri, isEmpty);
    });
  });
}
