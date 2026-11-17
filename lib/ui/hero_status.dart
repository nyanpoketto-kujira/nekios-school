/// Hero status sederhana (Fase 3) untuk status selain pelajaran:
/// satu kartu besar berisi kata status + countdown. Poles visual
/// per status menyusul di Fase 4; yang penting semua status tampil
/// fungsional dan tidak crash.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'tema.dart';

class HeroStatus extends StatelessWidget {
  const HeroStatus({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
    final slot = keadaan.slotAktif;
    final (kata, sub, warnaKartu, warnaTeks) = switch (keadaan.status) {
      StatusSekolah.istirahat => (
          slot?.label ?? 'ISTIRAHAT',
          'Bel berikutnya ${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}',
          TemaWarna.tertiaryContainer,
          TemaWarna.onTertiaryContainer,
        ),
      StatusSekolah.isoma => (
          slot?.label ?? 'ISOMA',
          'Bel berikutnya ${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}',
          TemaWarna.tertiaryContainer,
          TemaWarna.onTertiaryContainer,
        ),
      StatusSekolah.khusus => (
          slot?.label ?? 'KEGIATAN KHUSUS',
          'Selesai ${slot?.selesai ?? ''}',
          TemaWarna.secondaryContainer,
          TemaWarna.onSurface,
        ),
      StatusSekolah.sebelumMasuk => (
          'BELUM MASUK',
          'Bel masuk pukul ${keadaan.slotBerikutnya?.mulai ?? ''}',
          TemaWarna.primaryContainer,
          TemaWarna.onPrimaryContainer,
        ),
      StatusSekolah.pulang => (
          'SAMPAI JUMPA BESOK',
          keadaan.hariBerikutnya != null
              ? 'Besok (${keadaan.hariBerikutnya!.nama}) masuk '
                  '${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}'
              : '',
          TemaWarna.surfaceContainer,
          TemaWarna.onSurface,
        ),
      StatusSekolah.tidakAdaJadwal => (
          'TIDAK ADA JADWAL',
          keadaan.hariBerikutnya != null
              ? 'Sekolah berikutnya: ${keadaan.hariBerikutnya!.nama} '
                  '${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}'
              : '',
          TemaWarna.surfaceContainer,
          TemaWarna.onSurface,
        ),
      StatusSekolah.pelajaran => ('', '', TemaWarna.surfaceContainer,
          TemaWarna.onSurface),
    };
    final tampilCountdown = keadaan.sisaKeBel != null &&
        keadaan.status != StatusSekolah.pulang &&
        keadaan.status != StatusSekolah.tidakAdaJadwal;
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kata,
                  style: TextStyle(
                    color: warnaTeks,
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  sub,
                  style: TextStyle(
                    color: warnaTeks.withValues(alpha: 0.85),
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
          if (tampilCountdown)
            Text(
              formatCountdown(keadaan.sisaKeBel!),
              style: TextStyle(
                color: warnaTeks,
                fontSize: 110,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

String _jamTitik(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
