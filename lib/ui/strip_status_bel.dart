/// Strip status bel (Fase 3): chip status + Jam ke-N + rentang slot
/// di kiri; countdown menuju bel dan chip jam bel di kanan.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'tema.dart';

class StripStatusBel extends StatelessWidget {
  const StripStatusBel({super.key, required this.keadaan});

  final KeadaanTampilan keadaan;

  @override
  Widget build(BuildContext context) {
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
        color: TemaWarna.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: TemaWarna.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              kataChip,
              style: const TextStyle(
                color: TemaWarna.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              teksTengah,
              style: const TextStyle(
                color: TemaWarna.onSurface,
                fontSize: 24,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (keadaan.sisaKeBel != null &&
              keadaan.status != StatusSekolah.pulang &&
              keadaan.status != StatusSekolah.tidakAdaJadwal) ...[
            Text(
              formatCountdown(keadaan.sisaKeBel!),
              style: const TextStyle(
                color: TemaWarna.tertiary,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 22),
          ],
          if (teksBel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: TemaWarna.onSurfaceVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                teksBel,
                style: const TextStyle(
                  color: TemaWarna.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
