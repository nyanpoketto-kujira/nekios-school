/// Hero status (ADR-006) untuk status selain pelajaran — digaya
/// ulang ala PrayerStateOverlay masjid-you: tipografi display besar,
/// container tonal per status dengan pasangan on-container yang sah,
/// countdown besar tabular, dan progress tonal di dasar kartu.
///
/// Pemetaan container mengikuti spec color roles: ISOMA/istirahat =
/// tertiaryContainer, khusus/upacara = secondaryContainer, sebelum
/// masuk = primaryContainer, pulang/libur = surfaceContainer.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';

class HeroStatus extends StatelessWidget {
  const HeroStatus({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slot = keadaan.slotAktif;
    final (kata, sub, warnaKartu, warnaTeks) = switch (keadaan.status) {
      StatusSekolah.istirahat => (
          slot?.label ?? 'ISTIRAHAT',
          'Bel berikutnya ${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}',
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      StatusSekolah.isoma => (
          slot?.label ?? 'ISOMA',
          'Bel berikutnya ${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}',
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      StatusSekolah.khusus => (
          slot?.label ?? 'KEGIATAN KHUSUS',
          'Selesai ${slot?.selesai ?? ''}',
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      StatusSekolah.sebelumMasuk => (
          'BELUM MASUK',
          'Bel masuk pukul ${keadaan.slotBerikutnya?.mulai ?? ''}',
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      StatusSekolah.pulang => (
          'SAMPAI JUMPA BESOK',
          keadaan.hariBerikutnya != null
              ? 'Besok (${keadaan.hariBerikutnya!.nama}) masuk '
                  '${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}'
              : '',
          colorScheme.surfaceContainer,
          colorScheme.onSurface,
        ),
      StatusSekolah.tidakAdaJadwal => (
          'TIDAK ADA JADWAL',
          keadaan.hariBerikutnya != null
              ? 'Sekolah berikutnya: ${keadaan.hariBerikutnya!.nama} '
                  '${keadaan.belBerikutnya != null ? _jamTitik(keadaan.belBerikutnya!) : ''}'
              : '',
          colorScheme.surfaceContainer,
          colorScheme.onSurface,
        ),
      StatusSekolah.pelajaran => (
          '',
          '',
          colorScheme.surfaceContainer,
          colorScheme.onSurface,
        ),
    };
    final tampilCountdown = keadaan.sisaKeBel != null &&
        keadaan.status != StatusSekolah.pulang &&
        keadaan.status != StatusSekolah.tidakAdaJadwal;
    final progres = keadaan.progresSlot;
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kata,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: warnaTeks,
                          fontSize: 52,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sub,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: warnaTeks.withValues(alpha: 0.85),
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tampilCountdown)
                  Text(
                    formatCountdown(keadaan.sisaKeBel!),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: warnaTeks,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          if (progres != null) ...[
            const SizedBox(height: 18),
            // Progress tonal: rel = on-container redup, isi = warna
            // teks container itu sendiri (pasangan tonal yang aman).
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 12,
                color: warnaTeks.withValues(alpha: 0.18),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progres.clamp(0.0, 1.0),
                  child: Container(color: warnaTeks),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _jamTitik(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
