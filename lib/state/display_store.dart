/// DisplayStore nekios-school (Fase 2.5) — satu sumber kebenaran UI.
///
/// Store memegang snapshot tampilan: data jadwal, keadaan hasil mesin
/// jadwal, teks mading, offset simulasi jam, logo sekolah, dan status
/// koneksi remote. Semua perubahan masuk lewat [terima] sebagai
/// [DisplayEvent]; waktu berjalan lewat [tick] yang dipanggil berkala
/// (1 detik) oleh lapisan aplikasi. UI hanya membaca store dan
/// menggambar — tidak menghitung, tidak menyentuh sumber data.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/domain.dart';
import '../sources/events.dart';

/// Keadaan "Floating Spotlight Pergantian Jam" (ADR-017): slot
/// pelajaran yang baru dimulai + momen efektif mulainya. UI
/// menurunkan tampil/hilang (60 detik), halaman aktif, dan sisa
/// waktu murni dari nilai ini dan jam efektif — tanpa timer sendiri.
class KeadaanSpotlight {
  const KeadaanSpotlight({
    required this.slot,
    required this.jamKe,
    required this.mulaiEfektif,
  });

  /// Slot pelajaran yang sedang disorot.
  final Slot slot;

  /// Nomor "Jam ke-N" slot ini.
  final int jamKe;

  /// Momen (jam efektif) spotlight mulai tampil.
  final DateTime mulaiEfektif;

  /// Lama spotlight tampil setiap pergantian jam.
  static const Duration durasi = Duration(seconds: 60);
}

class DisplayStore extends ChangeNotifier {
  DisplayStore({bool belAktifAwal = true, this.simpanBelAktif})
    : belAktif = belAktifAwal;
  /// Data jadwal aktif; null sebelum [ScheduleReplaced] pertama.
  JadwalData? data;

  /// Snapshot keadaan tampilan terakhir; null sebelum data ada dan
  /// [tick] pertama berjalan.
  KeadaanTampilan? keadaan;

  /// Teks running text / mading saat ini.
  String mading = '';

  /// Geseran jam simulasi dari jam sistem.
  Duration offsetSimulasi = Duration.zero;

  /// True selama simulasi jam aktif (offset diterapkan).
  bool simulasiAktif = false;

  /// Byte gambar logo sekolah dari remote (Fase R1); null = tanpa
  /// logo. Diteruskan apa adanya ke HeaderSekolah (ADR-008).
  Uint8List? logoBytes;

  /// True selama ada remote (klien WebSocket) tersambung (Fase R1);
  /// menggerakkan indikator halus "Remote terhubung" di UI.
  bool remoteTerhubung = false;

  /// Saklar bel sekolah (ADR-017): false = pengumuman tidak berbunyi
  /// (spotlight pergantian jam tetap tampil — visual bukan suara).
  /// Nilai awal dari penyimpanan persisten lewat konstruktor;
  /// perubahan diteruskan ke [simpanBelAktif].
  bool belAktif;

  /// Penulis saklar bel persisten (komposisi aplikasi); null =
  /// perubahan hanya berlaku sesi ini (dipakai test).
  final void Function(bool aktif)? simpanBelAktif;

  /// Pengumuman bel terakhir yang benar-benar diputar: nama berkas
  /// aset + momen efektif pemutarannya. Masuk `state.snapshot` agar
  /// remote (dan verifikasi) bisa membuktikan bel berbunyi.
  ({String berkas, DateTime pada})? belTerakhir;

  /// Spotlight pergantian jam yang aktif; null = tidak tampil.
  /// Diatur deteksi transisi; UI menyembunyikannya sendiri setelah
  /// [KeadaanSpotlight.durasi] lewat dari `mulaiEfektif`.
  KeadaanSpotlight? spotlight;

  final StreamController<String> _kontrolBel =
      StreamController<String>.broadcast();

  /// Aliran perintah putar bel: nama berkas aset (mis.
  /// `audio/bel_jam_3.mp3`) yang harus diputar lapisan aplikasi
  /// lewat pemutar platform. Store sendiri tidak menyentuh audio.
  Stream<String> get streamBel => _kontrolBel.stream;

  /// Telan satu deteksi transisi berikutnya: diatur saat event yang
  /// menggeser keadaan BUKAN karena bel wajar (jadwal diganti,
  /// simulasi diakhiri) — momen-momen itu bukan bunyi bel.
  bool _telanTransisi = false;

  DateTime? _nowSistemTerakhir;

  /// Jam efektif yang sedang ditampilkan: momen yang dipakai
  /// snapshot [keadaan] terakhir; sebelum keadaan pertama ada,
  /// diturunkan dari jam sistem terakhir + offset simulasi.
  /// Null sebelum [tick] pertama.
  DateTime? get jamEfektif =>
      keadaan?.sekarang ?? _nowSistemTerakhir?.add(offsetSimulasi);

  /// Terapkan satu [event], hitung ulang keadaan, lalu beri tahu
  /// pendengar. Event bersifat jarang dan selalu bermakna, jadi
  /// [terima] selalu memanggil [notifyListeners] (lihat ADR-004).
  void terima(DisplayEvent event) {
    switch (event) {
      case ScheduleReplaced(:final data):
        this.data = data;
        // Jadwal diganti = keadaan bisa meloncat; itu bukan bunyi
        // bel (ADR-017).
        _telanTransisi = true;
      case MadingChanged(:final teks):
        mading = teks;
      case ClockSimulated(:final offset):
        offsetSimulasi = offset;
        simulasiAktif = true;
      case ClockSimulationCleared():
        offsetSimulasi = Duration.zero;
        simulasiAktif = false;
        // Kembali ke jam asli menggeser keadaan ke slot waktu nyata;
        // bukan bunyi bel (ADR-017).
        _telanTransisi = true;
      case LogoChanged(:final bytes):
        logoBytes = bytes;
      case BelKonfigurasiChanged(:final aktif):
        belAktif = aktif;
        simpanBelAktif?.call(aktif);
      case TesBelDiminta():
        mintaTesBel();
      case RemoteConnectionChanged(:final terhubung):
        remoteTerhubung = terhubung;
    }
    final sebelum = keadaan;
    _hitungUlang();
    _periksaTransisi(sebelum, keadaan);
    notifyListeners();
  }

  /// Majukan waktu: hitung keadaan untuk `nowSistem + offsetSimulasi`.
  ///
  /// [notifyListeners] hanya dipanggil bila snapshot berubah pada
  /// resolusi detik (status, slot aktif, atau sisa bel) — cukup untuk
  /// countdown per detik dan progres slot, tanpa membangun ulang UI
  /// saat tidak ada yang berubah (lihat ADR-004).
  void tick(DateTime nowSistem) {
    _nowSistemTerakhir = nowSistem;
    final sebelum = keadaan;
    _hitungUlang();
    final sesudah = keadaan;
    _periksaTransisi(sebelum, sesudah);
    if (!_snapshotSama(sebelum, sesudah)) {
      notifyListeners();
    }
  }

  /// Deteksi transisi bel dari dua snapshot berurutan (ADR-017).
  ///
  /// Bel berbunyi saat display MASUK slot baru (identitas slot =
  /// hari + indeks berubah) atau saat hari berakhir (status menjadi
  /// pulang dari status lain). Loncat simulasi jam ikut memicu —
  /// itulah jalur demo pameran — kecuali transisi yang ditelan
  /// [_telanTransisi] (ganti jadwal / akhiri simulasi).
  void _periksaTransisi(KeadaanTampilan? sebelum, KeadaanTampilan? sesudah) {
    if (_telanTransisi) {
      _telanTransisi = false;
      return;
    }
    if (sebelum == null || sesudah == null) return;
    final slotBaru = sesudah.slotAktif;
    final kunciSebelum = sebelum.slotAktif == null
        ? null
        : '${sebelum.hariIni?.nama}|${sebelum.indeksAktif}';
    final kunciSesudah = slotBaru == null
        ? null
        : '${sesudah.hariIni?.nama}|${sesudah.indeksAktif}';
    if (slotBaru != null && kunciSesudah != kunciSebelum) {
      final berkas = berkasBelUntukSlot(slotBaru, sesudah.jamKeAktif);
      if (berkas != null) _bunyi(berkas, sesudah.sekarang);
      spotlight = slotBaru.adalahPelajaran
          ? KeadaanSpotlight(
              slot: slotBaru,
              jamKe: sesudah.jamKeAktif ?? 0,
              mulaiEfektif: sesudah.sekarang,
            )
          : null;
    } else if (slotBaru == null &&
        sesudah.status == StatusSekolah.pulang &&
        sebelum.status != StatusSekolah.pulang) {
      _bunyi(kBerkasBelPulang, sesudah.sekarang);
      spotlight = null;
    }
  }

  /// Minta pemutaran [berkas] ke lapisan aplikasi + catat sebagai
  /// bel terakhir. Dihormati saklar [belAktif]: nonaktif = diam
  /// (dan tidak tercatat sebagai bel yang berbunyi).
  void _bunyi(String berkas, DateTime pada) {
    if (!belAktif) return;
    belTerakhir = (berkas: berkas, pada: pada);
    _kontrolBel.add(berkas);
  }

  /// Uji suara bel (paket `audio.tes`): putar pengumuman slot yang
  /// sedang berjalan — di luar jam slot, putar contoh jam ke-1.
  /// Selalu berbunyi, juga saat [belAktif] nonaktif.
  void mintaTesBel() {
    final k = keadaan;
    final slot = k?.slotAktif;
    final berkas = (slot == null
            ? null
            : berkasBelUntukSlot(slot, k!.jamKeAktif)) ??
        kBerkasBelContoh;
    belTerakhir = (berkas: berkas, pada: k?.sekarang ?? DateTime.now());
    _kontrolBel.add(berkas);
  }

  void _hitungUlang() {
    final d = data;
    final nowSistem = _nowSistemTerakhir;
    if (d == null || nowSistem == null) {
      keadaan = null;
      return;
    }
    keadaan = hitungKeadaan(d, nowSistem.add(offsetSimulasi));
  }

  /// Potret keadaan display sebagai payload paket `state.snapshot`
  /// nekios-core (Fase R1, ADR-013) — jawaban atas `ping` remote.
  ///
  /// Bentuk payload ini kontrak milik nekios-school (PROTOCOL.md
  /// core §3.2) dan dibaca nekios-remote (R2) untuk cermin keadaan:
  /// - `status`: nama [StatusSekolah] saat ini, atau `'belumSiap'`
  ///   sebelum data jadwal + tick pertama ada.
  /// - `jamEfektif`: ISO-8601 jam yang sedang ditampilkan (sudah
  ///   termasuk offset simulasi); null sebelum tick pertama.
  /// - `simulasiAktif`: apakah jam sedang disimulasikan.
  /// - `mading`: teks mading aktif ('' = teks sambutan bawaan).
  /// - `hasLogo`: apakah logo sekolah terpasang.
  /// - `jamKeAktif`: "Jam ke-N" slot aktif; null di luar pelajaran.
  /// - `slotAktif`: `{mulai, selesai, tipe, label}` slot aktif;
  ///   null bila tidak ada slot yang sedang berlangsung.
  /// - `belBerikutnya`: ISO-8601 bunyi bel berikutnya; null bila
  ///   data tidak punya jadwal sama sekali.
  /// - `sisaKeBelDetik`: sisa detik menuju bel berikutnya.
  /// - `jadwal`: ringkasan `{sekolah, judul, tahunPelajaran,
  ///   jurusan, jumlahKelas, jumlahHari, hariAktif}`; null sebelum
  ///   ada data jadwal.
  Map<String, dynamic> snapshotPaket() {
    final k = keadaan;
    final d = data;
    final slot = k?.slotAktif;
    return {
      'status': k?.status.name ?? 'belumSiap',
      'jamEfektif': jamEfektif?.toIso8601String(),
      'simulasiAktif': simulasiAktif,
      'mading': mading,
      'hasLogo': logoBytes != null,
      'jamKeAktif': k?.jamKeAktif,
      'slotAktif': slot == null
          ? null
          : {
              'mulai': slot.mulai,
              'selesai': slot.selesai,
              'tipe': slot.tipe.name,
              'label': slot.label,
            },
      'belBerikutnya': k?.belBerikutnya?.toIso8601String(),
      'sisaKeBelDetik': k?.sisaKeBel?.inSeconds,
      'belAktif': belAktif,
      'belTerakhir': belTerakhir == null
          ? null
          : {
              'berkas': belTerakhir!.berkas,
              'pada': belTerakhir!.pada.toIso8601String(),
            },
      'jadwal': d == null
          ? null
          : {
              'sekolah': d.sekolah,
              'judul': d.judul,
              'tahunPelajaran': d.tahunPelajaran,
              'jurusan': d.jurusan,
              'jumlahKelas': d.kelas.length,
              'jumlahHari': d.hari.length,
              'hariAktif': k?.hariIni?.nama,
            },
    };
  }

  @override
  void dispose() {
    unawaited(_kontrolBel.close());
    super.dispose();
  }

  bool _snapshotSama(KeadaanTampilan? a, KeadaanTampilan? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.status == b.status &&
        a.indeksAktif == b.indeksAktif &&
        a.sisaKeBel?.inSeconds == b.sisaKeBel?.inSeconds &&
        a.progresSlot == b.progresSlot;
  }
}
