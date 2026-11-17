/// Validasi data jadwal — implementasi aturan §7 dokumen arsitektur.
///
/// Mengembalikan daftar pesan kesalahan; daftar kosong berarti valid.
/// Fungsi ini murni (tanpa IO) supaya bisa dipakai loader asset,
/// sumber WebSocket nekios-core nanti, dan unit test.
library;

import 'models.dart';

List<String> validasiJadwal(JadwalData data) {
  final errors = <String>[];
  final kgValid = data.guru.map((g) => g.kg).toSet();
  final mapelValid = data.mapel.map((m) => m.kode).toSet();
  final kelasValid = data.kelas.map((k) => k.id).toSet();
  final polaWarna = RegExp(r'^#[0-9A-Fa-f]{6}$');

  // Aturan 5: setiap mapel punya namaPanjang dan warna (#RRGGBB).
  for (final m in data.mapel) {
    if (m.namaPanjang.trim().isEmpty) {
      errors.add('Mapel ${m.kode}: namaPanjang kosong.');
    }
    if (!polaWarna.hasMatch(m.warna)) {
      errors.add('Mapel ${m.kode}: warna "${m.warna}" bukan format #RRGGBB.');
    }
  }

  for (final hari in data.hari) {
    for (var i = 0; i < hari.slots.length; i++) {
      final slot = hari.slots[i];
      final konteks = '${hari.nama} slot ${slot.mulai}–${slot.selesai}';

      // Aturan 4: mulai < selesai di semua slot.
      if (slot.mulaiMenit >= slot.selesaiMenit) {
        errors.add('$konteks: mulai harus sebelum selesai.');
      }

      // Aturan 1: slot terurut dan tidak tumpang tindih dalam satu hari.
      if (i > 0) {
        final prev = hari.slots[i - 1];
        if (slot.mulaiMenit < prev.mulaiMenit) {
          errors.add('$konteks: slot tidak terurut (sebelumnya ${prev.mulai}).');
        }
        if (slot.mulaiMenit < prev.selesaiMenit) {
          errors.add(
            '$konteks: tumpang tindih dengan slot sebelumnya '
            '(${prev.mulai}–${prev.selesai}).',
          );
        }
      }

      // Aturan 3: slot pelajaran tepat satu entri per kelas;
      // slot non-pelajaran tidak boleh punya entri.
      if (slot.adalahPelajaran) {
        if (slot.entri.length != data.kelas.length ||
            !slot.entri.keys.toSet().containsAll(kelasValid)) {
          errors.add(
            '$konteks: slot pelajaran wajib punya tepat '
            '${data.kelas.length} entri (satu per kelas).',
          );
        }
      } else if (slot.entri.isNotEmpty) {
        errors.add('$konteks: slot ${slot.tipe.name} tidak boleh punya entri.');
      }

      // Aturan 2: foreign key entri harus ada di tabel referensi.
      for (final e in slot.entri.entries) {
        if (!kelasValid.contains(e.key)) {
          errors.add('$konteks: kelas tidak dikenal "${e.key}".');
        }
        if (!mapelValid.contains(e.value.mapel)) {
          errors.add('$konteks: mapel tidak dikenal "${e.value.mapel}".');
        }
        if (!kgValid.contains(e.value.kg)) {
          errors.add('$konteks: KG tidak dikenal ${e.value.kg}.');
        }
      }
    }
  }
  return errors;
}
