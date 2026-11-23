import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/models.dart';
import 'package:nekios_school/domain/validasi.dart';

Map<String, dynamic> muatJsonMentah() {
  final berkas = File('assets/jadwal-tkj.json');
  return jsonDecode(berkas.readAsStringSync()) as Map<String, dynamic>;
}

/// Salinan dalam (deep copy) JSON asli supaya bisa dimutasi per test.
Map<String, dynamic> salinan() =>
    jsonDecode(jsonEncode(muatJsonMentah())) as Map<String, dynamic>;

void main() {
  group('validasiJadwal — data asli', () {
    test('jadwal-tkj.json lolos semua aturan §7', () {
      final data = JadwalData.fromJson(muatJsonMentah());
      expect(validasiJadwal(data), isEmpty);
    });

    test('isi data sesuai harapan (18 kelas, 36 guru, 5 hari)', () {
      final data = JadwalData.fromJson(muatJsonMentah());
      expect(data.kelas.length, 18);
      expect(data.guru.length, 36);
      expect(data.hari.length, 5);
      expect(data.sekolah, 'SMKN 1 UKUI');
    });
  });

  group('validasiJadwal — pelanggaran per aturan', () {
    test('aturan 1: slot tumpang tindih ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      // Slot kedua mulai sebelum slot pertama selesai.
      (selasa['slots'] as List)[1]['mulai'] = '08.00';
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('tumpang tindih'));
    });

    test('aturan 2: KG tidak dikenal ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      final slot = (selasa['slots'] as List)[2];
      (slot['entri'] as Map)['X-TKJ-A']['kg'] = 999;
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('KG tidak dikenal 999'));
    });

    test('aturan 2: mapel tidak dikenal ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      final slot = (selasa['slots'] as List)[2];
      (slot['entri'] as Map)['X-TKJ-A']['mapel'] = 'XXXX';
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('mapel tidak dikenal'));
    });

    test('aturan 3: slot pelajaran kurang entri ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      final slot = (selasa['slots'] as List)[2];
      (slot['entri'] as Map).remove('XII-TKJ-B');
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('tepat 18 entri'));
    });

    test('aturan 3: slot istirahat berisi entri ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      final istirahat = (selasa['slots'] as List)
          .firstWhere((s) => s['tipe'] == 'istirahat');
      istirahat['entri'] = {
        'X-TKJ-A': {'mapel': 'IPAS', 'kg': 7},
      };
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('tidak boleh punya entri'));
    });

    test('aturan 4: mulai >= selesai ditolak', () {
      final json = salinan();
      final selasa = (json['hari'] as List)[1];
      (selasa['slots'] as List)[0]['selesai'] = '07.30';
      final data = JadwalData.fromJson(json);
      expect(validasiJadwal(data).join(' '), contains('mulai harus sebelum selesai'));
    });

    test('aturan 5: mapel tanpa namaPanjang / warna rusak ditolak', () {
      final json = salinan();
      (json['mapel'] as List)[0]['namaPanjang'] = '';
      (json['mapel'] as List)[1]['warna'] = 'kuning';
      final data = JadwalData.fromJson(json);
      final pesan = validasiJadwal(data).join(' ');
      expect(pesan, contains('namaPanjang kosong'));
      expect(pesan, contains('#RRGGBB'));
    });
  });
}
