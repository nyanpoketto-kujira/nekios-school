/// Galeri foto kegiatan sekolah — KHUSUS BUILD PAMERAN.
///
/// Branch `feat/pameran-galeri-mock` (jangan di-merge ke main):
/// 10 foto kegiatan SMKN 1 Ukui ter-bundle sebagai aset dan tampil
/// layar penuh secara berkala di atas konten utama, di bawah
/// Spotlight Pergantian Jam (spotlight tetap menutupi galeri).
///
/// Pola waktu (siklus 90 detik):
/// - 45 detik pertama: konten utama (jadwal) yang tampil.
/// - 45 detik berikutnya: galeri tampil, foto berganti tiap
///   9 detik dengan fade — satu putaran galeri menayangkan
///   5 foto; siklus berikutnya melanjutkan 5 foto sisanya.
///
/// Murni lapisan UI: tidak membaca store, tidak menerima perintah
/// remote. Timer-nya meniru pola rotasi halaman di layar utama
/// (Timer.periodic + setState, dibatalkan saat dispose).
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Foto galeri bawaan build pameran (aset lokal, urutan tayang).
const daftarFotoGaleriPameran = <String>[
  'assets/galeri/foto-01.jpg',
  'assets/galeri/foto-02.jpg',
  'assets/galeri/foto-03.jpg',
  'assets/galeri/foto-04.jpg',
  'assets/galeri/foto-05.jpg',
  'assets/galeri/foto-06.jpg',
  'assets/galeri/foto-07.jpg',
  'assets/galeri/foto-08.jpg',
  'assets/galeri/foto-09.jpg',
  'assets/galeri/foto-10.jpg',
];

/// Overlay galeri foto layar penuh dengan pola waktu berkala.
///
/// Dipasang sebagai satu lapisan di Stack layar utama; saat tidak
/// dalam jendela tampil, widget ini tidak menggambar apa pun.
class GaleriKegiatan extends StatefulWidget {
  const GaleriKegiatan({super.key});

  /// Panjang satu siklus penuh (konten utama + galeri).
  static const int durasiSiklusDetik = 90;

  /// Detik dalam siklus saat galeri mulai tampil.
  static const int detikMulaiTampil = 45;

  /// Lama satu foto tayang sebelum berganti.
  static const int durasiPerFotoDetik = 9;

  /// Apakah galeri tampil pada [detik] sejak aplikasi berjalan.
  static bool tampilPada(int detik) =>
      detik % durasiSiklusDetik >= detikMulaiTampil;

  /// Indeks foto yang tayang pada [detik] sejak aplikasi berjalan.
  static int indeksFotoPada(int detik) =>
      (detik ~/ durasiPerFotoDetik) % daftarFotoGaleriPameran.length;

  @override
  State<GaleriKegiatan> createState() => _GaleriKegiatanState();
}

class _GaleriKegiatanState extends State<GaleriKegiatan> {
  Timer? _timer;
  int _detik = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _detik++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!GaleriKegiatan.tampilPada(_detik)) {
      return const SizedBox.shrink();
    }
    final foto = daftarFotoGaleriPameran[GaleriKegiatan.indeksFotoPada(_detik)];
    final theme = Theme.of(context);
    // Pemanggil membungkus widget ini dengan Positioned.fill di
    // Stack layar utama; di sini cukup Stack yang mengembang.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto layar penuh dengan fade antar foto.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          child: Image.asset(
            foto,
            key: ValueKey<String>(foto),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // Aset yang gagal dibaca tidak boleh meruntuhkan
            // display: jatuh ke latar polos skema warna.
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: theme.colorScheme.surfaceContainerLowest),
          ),
        ),
        // Gradien pengaman keterbacaan keterangan di dasar layar.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xB8000000)],
            ),
          ),
        ),
        Positioned(
          left: 40,
          right: 40,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Galeri Kegiatan Sekolah',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SMKN 1 Ukui',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
