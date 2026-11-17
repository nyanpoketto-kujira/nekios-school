/// Helper format tampilan (Fase 3): jam, countdown, tanggal Indonesia
/// manual (tanpa paket intl), dan nama pendek guru untuk chip.
library;

import '../domain/domain.dart';

String _dua(int n) => n.toString().padLeft(2, '0');

/// "09:20:24".
String formatJam(DateTime t) => '${_dua(t.hour)}:${_dua(t.minute)}:${_dua(t.second)}';

/// Countdown bel: "24:36", atau "1:05:09" bila lewat satu jam.
String formatCountdown(Duration d) {
  final negatif = d.isNegative;
  final v = negatif ? -d : d;
  final jam = v.inHours;
  final menit = _dua(v.inMinutes % 60);
  final detik = _dua(v.inSeconds % 60);
  final inti = jam > 0 ? '$jam:$menit:$detik' : '$menit:$detik';
  return negatif ? '-$inti' : inti;
}

const _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "Selasa, 17 November 2026".
String formatTanggal(DateTime t) =>
    '${_namaHari[t.weekday - 1]}, ${t.day} ${_namaBulan[t.month - 1]} ${t.year}';

/// Nama hari kapital, mis. "SELASA" untuk judul timeline.
String namaHariKapital(DateTime t) => _namaHari[t.weekday - 1].toUpperCase();

/// Nama pendek guru untuk chip 2 baris ("Bu Eva", "Pak Yusuf").
///
/// Peta kurasi mengikuti board desain untuk KG yang muncul di sana;
/// KG lain jatuh ke kata pertama nama lengkap. Ini data tampilan
/// sementara — idealnya kelak jadi field data guru sendiri.
const _namaPendekKurasi = <int, String>{
  5: 'Bu Rini',
  6: 'Pak Rudi',
  7: 'Bu Eva',
  10: 'Pak Edie',
  12: 'Bu Erni',
  14: 'Bu Eka',
  15: 'Bu Dosfriyati',
  16: 'Pak Sudirman',
  17: 'Pak Yoyon',
  20: 'Bu Sandra',
  21: 'Bu Sumiati',
  28: 'Bu Sinta',
  31: 'Bu Suci',
  33: 'Pak Yusuf',
  34: 'Bu Meizialisa',
};

String namaPendekGuru(Guru guru) {
  final kurasi = _namaPendekKurasi[guru.kg];
  if (kurasi != null) return kurasi;
  final tanpaGelar = guru.nama.split(',').first.trim();
  return tanpaGelar.split(' ').first;
}
