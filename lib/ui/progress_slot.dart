/// Progress slot bersama (Fase 3): label progres + sisa waktu di atas
/// bar primer — satu bar untuk semua kelas karena belnya bersamaan.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'tema.dart';

class ProgressSlot extends StatelessWidget {
  const ProgressSlot({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  color: TemaWarna.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Text(
              labelKanan,
              style: const TextStyle(
                color: TemaWarna.tertiary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 14,
            color: TemaWarna.surfaceContainerHigh,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progres,
              child: Container(color: TemaWarna.primary),
            ),
          ),
        ),
      ],
    );
  }
}
