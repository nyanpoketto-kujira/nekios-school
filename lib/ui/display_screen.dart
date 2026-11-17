/// Layar utama TV nekios-school (Fase 3).
///
/// Kanvas desain 1920×1080 diskalakan proporsional ke jendela aktual.
/// Layar hanya membaca [DisplayStore]: status pelajaran memakai tata
/// letak Varian J + rotasi kelas; status lain memakai hero sederhana.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../state/state.dart';
import 'header_sekolah.dart';
import 'hero_status.dart';
import 'indikator_halaman.dart';
import 'kartu_kelas.dart';
import 'progress_slot.dart';
import 'strip_status_bel.dart';
import 'tema.dart';
import 'timeline_jendela.dart';

class DisplayScreen extends StatelessWidget {
  const DisplayScreen({super.key, required this.store});

  final DisplayStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaWarna.latar,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: TemaWarna.ukuranKanvas.width,
              height: TemaWarna.ukuranKanvas.height,
              child: _isi(),
            ),
          );
        },
      ),
    );
  }

  Widget _isi() {
    final data = store.data;
    final keadaan = store.keadaan;
    if (data == null || keadaan == null) {
      return const Center(
        child: Text(
          'Memuat jadwal…',
          style: TextStyle(color: TemaWarna.onSurfaceVariant, fontSize: 28),
        ),
      );
    }
    if (keadaan.status == StatusSekolah.pelajaran) {
      return _LayarPelajaran(store: store, data: data, keadaan: keadaan);
    }
    // Status lain: header + strip + hero + timeline statis (Fase 4
    // akan memolesnya per status).
    final halaman = halamanRotasi(data.kelas);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 26, 48, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeaderSekolah(data: data, sekarang: keadaan.sekarang),
          const SizedBox(height: 18),
          StripStatusBel(keadaan: keadaan),
          const SizedBox(height: 20),
          HeroStatus(keadaan: keadaan),
          const SizedBox(height: 16),
          Expanded(
            child: TimelineJendela(
              data: data,
              keadaan: keadaan,
              kelasKolom: halaman.first,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayarPelajaran extends StatefulWidget {
  const _LayarPelajaran({
    required this.store,
    required this.data,
    required this.keadaan,
  });

  final DisplayStore store;
  final JadwalData data;
  final KeadaanTampilan keadaan;

  @override
  State<_LayarPelajaran> createState() => _LayarPelajaranState();
}

class _LayarPelajaranState extends State<_LayarPelajaran> {
  static const _durasiRotasi = Duration(seconds: 12);

  Timer? _timerRotasi;
  int _halaman = 0;

  @override
  void initState() {
    super.initState();
    _timerRotasi = Timer.periodic(_durasiRotasi, (_) {
      final jumlah = halamanRotasi(widget.data.kelas).length;
      if (jumlah > 1 && mounted) {
        setState(() => _halaman = (_halaman + 1) % jumlah);
      }
    });
  }

  @override
  void dispose() {
    _timerRotasi?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final keadaan = widget.keadaan;
    final halaman = halamanRotasi(data.kelas);
    final indeks = _halaman < halaman.length ? _halaman : 0;
    final kelasHalaman = halaman[indeks];
    final slot = keadaan.slotAktif;

    final barisKartu = SizedBox(
      height: 208,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kelasHalaman.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(
              child: slot?.entri[kelasHalaman[i].id] != null
                  ? KartuKelasSekarang(
                      kelas: kelasHalaman[i],
                      entri: slot!.entri[kelasHalaman[i].id]!,
                      data: data,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 26, 48, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeaderSekolah(data: data, sekarang: keadaan.sekarang),
          const SizedBox(height: 18),
          StripStatusBel(keadaan: keadaan),
          const SizedBox(height: 20),
          // Hanya area kartu + kolom timeline yang berotasi; header,
          // strip, dan progres tetap (pola board Rotasi 1/2).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(
              key: ValueKey<int>(indeks),
              child: barisKartu,
            ),
          ),
          const SizedBox(height: 14),
          ProgressSlot(keadaan: keadaan),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: KeyedSubtree(
                key: ValueKey<int>(indeks),
                child: TimelineJendela(
                  data: data,
                  keadaan: keadaan,
                  kelasKolom: kelasHalaman,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          IndikatorHalaman(jumlah: halaman.length, aktif: indeks),
        ],
      ),
    );
  }
}
