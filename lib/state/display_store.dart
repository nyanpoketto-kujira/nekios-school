/// DisplayStore nekios-school (Fase 2.5) — satu sumber kebenaran UI.
///
/// Store memegang snapshot tampilan: data jadwal, keadaan hasil mesin
/// jadwal, teks mading, dan offset simulasi jam. Semua perubahan masuk
/// lewat [terima] sebagai [DisplayEvent]; waktu berjalan lewat [tick]
/// yang dipanggil berkala (1 detik) oleh lapisan aplikasi. UI hanya
/// membaca store dan menggambar — tidak menghitung, tidak menyentuh
/// sumber data.
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

  DateTime? _nowSistemTerakhir;

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

  bool _snapshotSama(KeadaanTampilan? a, KeadaanTampilan? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.status == b.status &&
        a.indeksAktif == b.indeksAktif &&
        a.sisaKeBel?.inSeconds == b.sisaKeBel?.inSeconds &&
        a.progresSlot == b.progresSlot;
  }
}
