/// Strip status bel (ADR-006): bar pill surfaceContainer berisi chip
/// status + Jam ke-N + rentang slot di kiri; countdown menuju bel dan
/// chip jam bel di kanan. Warna dari role skema; countdown tabular.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';

class StripStatusBel extends StatelessWidget {
  const StripStatusBel({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slot = keadaan.slotAktif;
    final teksTengah = switch (keadaan.status) {
      StatusSekolah.pelajaran => 'Jam ke-${keadaan.jamKeAktif ?? '-'}'
          ' • Pelajaran sedang berlangsung'
          '${slot != null ? ' • ${slot.mulai}–${slot.selesai}' : ''}',
      StatusSekolah.istirahat => 'Istirahat'
          '${slot != null ? ' • ${slot.mulai}–${slot.selesai}' : ''}',
      StatusSekolah.isoma => 'ISOMA'
          '${slot != null ? ' • ${slot.mulai}–${slot.selesai}' : ''}',
      StatusSekolah.khusus =>
        '${slot?.label ?? 'Kegiatan khusus'}'
            '${slot != null ? ' • ${slot.mulai}–${slot.selesai}' : ''}',
      StatusSekolah.sebelumMasuk => 'Bel masuk'
          '${keadaan.slotBerikutnya != null ? ' • ${keadaan.slotBerikutnya!.mulai}' : ''}',
      StatusSekolah.pulang => 'Jam sekolah selesai',
      StatusSekolah.tidakAdaJadwal => 'Tidak ada jadwal hari ini',
    };
    final kataChip = switch (keadaan.status) {
      StatusSekolah.pelajaran => 'SEDANG BERLANGSUNG',
      StatusSekolah.istirahat => 'ISTIRAHAT',
      StatusSekolah.isoma => 'ISOMA',
      StatusSekolah.khusus => 'KHUSUS',
      StatusSekolah.sebelumMasuk => 'SEBELUM MASUK',
      StatusSekolah.pulang => 'PULANG',
      StatusSekolah.tidakAdaJadwal => 'LIBUR',
    };
    final bel = keadaan.belBerikutnya;
    final teksBel = bel == null
        ? null
        : 'BEL • ${bel.hour.toString().padLeft(2, '0')}'
            '.${bel.minute.toString().padLeft(2, '0')}';
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Chip status: pill ukuran natural, pasangan container/on
          // yang sah menurut spec color roles.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              kataChip,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              teksTengah,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 22,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (keadaan.sisaKeBel != null &&
              keadaan.status != StatusSekolah.pulang &&
              keadaan.status != StatusSekolah.tidakAdaJadwal) ...[
            Text(
              formatCountdown(keadaan.sisaKeBel!),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 30,
              ),
            ),
            const SizedBox(width: 22),
          ],
          if (teksBel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                teksBel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
