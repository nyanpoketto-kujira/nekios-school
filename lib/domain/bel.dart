/// Pemetaan bel sekolah (fitur Audio Bel, ADR-017).
///
/// Pengumuman bel adalah aset audio STATIS yang ter-bundel di aplikasi
/// (`assets/audio/`), disusun sebagai RANGKAIAN POTONGAN (chunk) —
/// konsep "Concatenative Audio Chunking" nyanpo: chime awal + info +
/// angka + chime akhir, diputar berurutan menyambung. Potongan yang
/// sama (chime, frasa info) hanya ada satu berkas dan dipakai bersama
/// oleh semua pengumuman, jadi mengganti suara/chime cukup menimpa
/// berkas potongannya saja. Modul murni ini memutuskan rangkaian mana
/// yang berbunyi untuk sebuah slot; pemutaran dan deteksi transisinya
/// urusan layer state.
///
/// Nama berkas LOGIS (`bel_jam_3.mp3` dst.) tetap dipertahankan
/// sebagai identitas pengumuman untuk `belTerakhir` di snapshot —
/// rangkaian chunk adalah urusan internal TV.
library;

import 'models.dart';

/// Berkas pengumuman bel pulang (akhir hari sekolah).
const String kBerkasBelPulang = 'audio/bel_pulang.mp3';

/// Berkas contoh untuk Tes Bel di luar jam slot (jam pelajaran ke-1).
const String kBerkasBelContoh = 'audio/bel_jam_1.mp3';

// ---------------------------------------------------------------------------
// Potongan (chunk) audio — dipotong dari rekaman pengumuman yang sama
// (suara MAI_01 varian A), lihat ~/workspace/audio-bel/chunks/.
// ---------------------------------------------------------------------------

/// Chime pembuka setiap pengumuman.
const String kCnkChimeAwal = 'audio/cnk_chime_awal.mp3';

/// Chime penutup setiap pengumuman.
const String kCnkChimeAkhir = 'audio/cnk_chime_akhir.mp3';

/// Frasa "Saatnya jam pelajaran" (angka menyusul sebagai chunk angka).
const String kCnkInfoJam = 'audio/cnk_info_jam.mp3';

/// Pengumuman istirahat utuh ("Waktunya istirahat.").
const String kCnkInfoIstirahat = 'audio/cnk_info_istirahat.mp3';

/// Pengumuman ISOMA utuh ("Waktunya istirahat, sholat, dan makan.").
const String kCnkInfoIsoma = 'audio/cnk_info_isoma.mp3';

/// Pengumuman upacara utuh ("Saatnya upacara dimulai.").
const String kCnkInfoUpacara = 'audio/cnk_info_upacara.mp3';

/// Pengumuman rohis utuh ("Saatnya rohis dimulai.").
const String kCnkInfoRohis = 'audio/cnk_info_rohis.mp3';

/// Pengumuman kegiatan khusus utuh ("Saatnya kegiatan dimulai.").
const String kCnkInfoKegiatan = 'audio/cnk_info_kegiatan.mp3';

/// Pengumuman pulang utuh ("Waktunya pulang. Hati-hati di jalan.").
const String kCnkInfoPulang = 'audio/cnk_info_pulang.mp3';

/// Chunk angka untuk "ke-N" + "dimulai." — potongan ekor kalimat jam
/// ke-[n] persis seperti terekam (memuat kata penghubung/ordinal dan
/// kata "dimulai."). Tersedia untuk n = 1..10 (seluruh jam nyata pada
/// jadwal); pola nama ini mendukung n berapa pun begitu asetnya ada.
String cnkAngka(int n) => 'audio/cnk_angka_$n.mp3';

/// Rangkaian bel pulang: chime + info pulang + chime akhir.
const List<String> kRangkaianBelPulang = [
  kCnkChimeAwal,
  kCnkInfoPulang,
  kCnkChimeAkhir,
];

/// Rangkaian contoh Tes Bel di luar jam slot (jam pelajaran ke-1).
const List<String> kRangkaianBelContoh = [
  kCnkChimeAwal,
  kCnkInfoJam,
  'audio/cnk_angka_1.mp3',
  kCnkChimeAkhir,
];

/// Rangkaian potongan pengumuman untuk [slot] yang baru dimulai;
/// [jamKe] adalah nomor "Jam ke-N" bila slot pelajaran. Null bila
/// slot tidak punya pengumuman (pelajaran tanpa nomor jam).
List<String>? rangkaianBelUntukSlot(Slot slot, int? jamKe) {
  return switch (slot.tipe) {
    SlotTipe.pelajaran =>
      jamKe == null
          ? null
          : [kCnkChimeAwal, kCnkInfoJam, cnkAngka(jamKe), kCnkChimeAkhir],
    SlotTipe.istirahat => const [
        kCnkChimeAwal,
        kCnkInfoIstirahat,
        kCnkChimeAkhir,
      ],
    SlotTipe.isoma => const [kCnkChimeAwal, kCnkInfoIsoma, kCnkChimeAkhir],
    SlotTipe.upacara => const [
        kCnkChimeAwal,
        kCnkInfoUpacara,
        kCnkChimeAkhir,
      ],
    SlotTipe.khusus => [
        kCnkChimeAwal,
        cnkInfoKhusus(slot.label),
        kCnkChimeAkhir,
      ],
  };
}

/// Chunk info untuk slot khusus dari labelnya (pasangan
/// [berkasBelKhusus] di dunia chunk).
String cnkInfoKhusus(String? label) {
  final l = (label ?? '').toLowerCase();
  if (l.contains('rohis') || l.contains('rokris')) {
    return kCnkInfoRohis;
  }
  return kCnkInfoKegiatan;
}

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
