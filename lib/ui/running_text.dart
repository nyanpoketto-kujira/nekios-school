/// Bar running text mading (ADR-006): full-width, menempel di dasar
/// layar di luar padding konten — meniru RunningTextBar masjid-you.
///
/// Teksnya dibaca dari `DisplayStore.mading` oleh pemanggil (event
/// `MadingChanged`, Fase 2.5); widget ini hanya menggambar + menggeser.
/// Bila mading kosong, tampil teks sambutan default sekolah. Marquee
/// sederhana: jeda di awal, scroll horizontal berulang, jeda lagi
/// setiap putaran.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'skala_tampilan.dart';

class RunningTextMading extends StatefulWidget {
  const RunningTextMading({
    super.key,
    required this.teks,
    this.namaSekolah,
  });

  /// Teks mading aktif dari store (boleh kosong).
  final String teks;

  /// Nama sekolah untuk teks sambutan default.
  final String? namaSekolah;

  /// Teks yang benar-benar ditampilkan: mading bila ada, default bila
  /// kosong.
  String get teksEfektif {
    final t = teks.trim();
    if (t.isNotEmpty) return t;
    final nama = (namaSekolah ?? '').trim();
    return 'Selamat datang di ${nama.isEmpty ? 'SMKN 1 UKUI' : nama} '
        '• Selamat belajar, tetap semangat, dan jaga ketertiban sekolah.';
  }

  @override
  State<RunningTextMading> createState() => _RunningTextMadingState();
}

class _RunningTextMadingState extends State<RunningTextMading> {
  /// Langkah timer marquee; jeda awal 2 detik = 40 langkah.
  static const _langkahJeda = 40;

  final ScrollController _kontrol = ScrollController();
  Timer? _timer;
  int _jeda = _langkahJeda;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mulai());
  }

  @override
  void didUpdateWidget(RunningTextMading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teksEfektif != widget.teksEfektif) {
      // Teks baru: mulai lagi dari awal dengan jeda.
      if (_kontrol.hasClients) _kontrol.jumpTo(0);
      _jeda = _langkahJeda;
      if (_timer == null || !_timer!.isActive) _mulai();
    }
  }

  void _mulai() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_kontrol.hasClients) return;
      if (_jeda > 0) {
        _jeda--;
        return;
      }
      final maks = _kontrol.position.maxScrollExtent;
      if (maks <= 0) return; // teks muat di layar: diam saja
      if (_kontrol.offset >= maks - 0.5) {
        _kontrol.jumpTo(0);
        _jeda = _langkahJeda;
      } else {
        _kontrol.jumpTo(_kontrol.offset + 2.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = SkalaTampilan.of(context);

    return Container(
      height: 52 * s,
      color: colorScheme.surfaceContainer,
      child: Row(
        children: [
          // Badge MADING — flush menyatu dengan bar, stadium hanya di
          // sisi kanan (pola badge INFORMASI masjid-you).
          Container(
            height: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20 * s),
            decoration: ShapeDecoration(
              color: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(26 * s),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: colorScheme.onPrimary,
                  size: 24 * s,
                ),
                SizedBox(width: 8 * s),
                Text(
                  'MADING',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 16 * s,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _kontrol,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16 * s),
              children: [
                Center(
                  child: Text(
                    widget.teksEfektif,
                    softWrap: false,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 20 * s,
                    ),
                  ),
                ),
                SizedBox(width: 240 * s), // ruang sebelum putaran ulang
              ],
            ),
          ),
        ],
      ),
    );
  }
}
