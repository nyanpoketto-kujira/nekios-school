/// Strip status bel (ADR-006): bar pill surfaceContainer berisi chip
/// status + Jam ke-N + rentang slot di kiri; countdown menuju bel dan
/// chip jam bel di kanan. Warna dari role skema; countdown tabular.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'skala_tampilan.dart';

class StripStatusBel extends StatelessWidget {
  const StripStatusBel({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = SkalaTampilan.of(context);
    final slot = keadaan.slotAktif;
    // Teks tengah pelajaran sengaja ringkas ("Pelajaran berlangsung",
    // tanpa rentang slot — rentang sudah tampil di label progres dan
    // timeline) supaya tidak ter-ellipsis menabrak countdown.
    final teksTengah = switch (keadaan.status) {
      StatusSekolah.pelajaran => 'Jam ke-${keadaan.jamKeAktif ?? '-'}'
          ' • Pelajaran berlangsung',
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
      height: 60 * s,
      padding: EdgeInsets.symmetric(horizontal: 20 * s),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30 * s),
      ),
      child: Row(
        children: [
          // Chip status: pill ukuran natural, pasangan container/on
          // yang sah menurut spec color roles.
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 16 * s, vertical: 7 * s),
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
                fontSize: 15 * s,
              ),
            ),
          ),
          SizedBox(width: 22 * s),
          Expanded(
            child: Text(
              teksTengah,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 22 * s,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (keadaan.sisaKeBel != null &&
              keadaan.status != StatusSekolah.pulang &&
              keadaan.status != StatusSekolah.tidakAdaJadwal) ...[
            // Celah tetap sebelum countdown: teks tengah yang menyusut
            // tidak pernah menempel ke angka countdown.
            SizedBox(width: 22 * s),
            Text(
              formatCountdown(keadaan.sisaKeBel!),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 30 * s,
              ),
            ),
            SizedBox(width: 22 * s),
          ],
          if (teksBel != null)
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 16 * s, vertical: 7 * s),
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
                  fontSize: 15 * s,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
