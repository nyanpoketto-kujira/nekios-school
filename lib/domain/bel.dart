/// Pemetaan bel sekolah (fitur Audio Bel, ADR-017).
///
/// Pengumuman bel adalah aset audio STATIS yang ter-bundel di aplikasi
/// (`assets/audio/`) — satu file per jenis pengumuman, chime sudah
/// menyatu di awal file. Modul murni ini memutuskan berkas mana yang
/// berbunyi untuk sebuah slot; pemutaran dan deteksi transisinya
/// urusan layer state.
library;

import 'models.dart';

/// Berkas pengumuman bel pulang (akhir hari sekolah).
const String kBerkasBelPulang = 'audio/bel_pulang.mp3';

/// Berkas contoh untuk Tes Bel di luar jam slot (jam pelajaran ke-1).
const String kBerkasBelContoh = 'audio/bel_jam_1.mp3';

/// Berkas pengumuman untuk [slot] yang baru dimulai; [jamKe] adalah
/// nomor "Jam ke-N" bila slot pelajaran. Null bila slot tidak punya
/// pengumuman (pelajaran tanpa nomor jam — tidak terjadi pada data
/// valid, tapi pemanggil tidak boleh jatuh karenanya).
String? berkasBelUntukSlot(Slot slot, int? jamKe) {
  return switch (slot.tipe) {
    SlotTipe.pelajaran =>
      jamKe == null ? null : 'audio/bel_jam_$jamKe.mp3',
    SlotTipe.istirahat => 'audio/bel_istirahat.mp3',
    SlotTipe.isoma => 'audio/bel_isoma.mp3',
    SlotTipe.upacara => 'audio/bel_upacara.mp3',
    SlotTipe.khusus => berkasBelKhusus(slot.label),
  };
}

/// Pemetaan slot khusus dari labelnya: ROHIS/ROKRIS punya pengumuman
/// sendiri; kegiatan khusus lain (kokurikuler, ekstrakurikuler, senam,
/// dst.) memakai pengumuman kegiatan generik.
String berkasBelKhusus(String? label) {
  final l = (label ?? '').toLowerCase();
  if (l.contains('rohis') || l.contains('rokris')) {
    return 'audio/bel_rohis.mp3';
  }
  return 'audio/bel_kegiatan.mp3';
}
