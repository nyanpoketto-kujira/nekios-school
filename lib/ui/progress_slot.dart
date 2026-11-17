/// Progress slot bersama (ADR-006): label progres + sisa waktu di
/// atas bar primary — satu bar untuk semua kelas karena belnya
/// bersamaan. Warna dari role skema; angka sisa tabular.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'skala_tampilan.dart';

class ProgressSlot extends StatelessWidget {
  const ProgressSlot({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = SkalaTampilan.of(context);
    final slot = keadaan.slotAktif;
    final progres = (keadaan.progresSlot ?? 0).clamp(0.0, 1.0);
    final labelKiri = keadaan.jamKeAktif != null && slot != null
        ? 'PROGRES JAM KE-${keadaan.jamKeAktif} • ${slot.mulai}–${slot.selesai}'
        : 'PROGRES SLOT';
    final bel = keadaan.belBerikutnya;
    final labelKanan = keadaan.sisaKeBel != null
        ? 'Sisa ${formatCountdown(keadaan.sisaKeBel!)}'
            '${bel != null ? ' • bel berikutnya ${bel.hour.toString().padLeft(2, '0')}.${bel.minute.toString().padLeft(2, '0')}' : ''}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                labelKiri,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontSize: 15 * s,
                ),
              ),
            ),
            Text(
              labelKanan,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 16 * s,
              ),
            ),
          ],
        ),
        SizedBox(height: 9 * s),
        ClipRRect(
          borderRadius: BorderRadius.circular(7 * s),
          child: Container(
            height: 14 * s,
            color: colorScheme.surfaceContainerHigh,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progres,
              child: Container(color: colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
