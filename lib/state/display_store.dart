/// DisplayStore nekios-school (Fase 2.5) — satu sumber kebenaran UI.
///
/// Store memegang snapshot tampilan: data jadwal, keadaan hasil mesin
/// jadwal, teks mading, offset simulasi jam, logo sekolah, dan status
/// koneksi remote. Semua perubahan masuk lewat [terima] sebagai
/// [DisplayEvent]; waktu berjalan lewat [tick] yang dipanggil berkala
/// (1 detik) oleh lapisan aplikasi. UI hanya membaca store dan
/// menggambar — tidak menghitung, tidak menyentuh sumber data.
library;

import 'package:flutter/foundation.dart';

import '../domain/domain.dart';
import '../sources/events.dart';

class DisplayStore extends ChangeNotifier {
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
      case MadingChanged(:final teks):
        mading = teks;
      case ClockSimulated(:final offset):
        offsetSimulasi = offset;
        simulasiAktif = true;
      case ClockSimulationCleared():
        offsetSimulasi = Duration.zero;
        simulasiAktif = false;
      case LogoChanged(:final bytes):
        logoBytes = bytes;
      case RemoteConnectionChanged(:final terhubung):
        remoteTerhubung = terhubung;
    }
    _hitungUlang();
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
    if (!_snapshotSama(sebelum, sesudah)) {
      notifyListeners();
    }
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

  bool _snapshotSama(KeadaanTampilan? a, KeadaanTampilan? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.status == b.status &&
        a.indeksAktif == b.indeksAktif &&
        a.sisaKeBel?.inSeconds == b.sisaKeBel?.inSeconds &&
        a.progresSlot == b.progresSlot;
  }
}
