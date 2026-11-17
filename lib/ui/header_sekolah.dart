/// Header sekolah (ADR-006): Card ala HeaderClock masjid-you —
/// kotak logo 1:1 + nama/subjudul sekolah di kiri, jam di dalam
/// kapsul ArchBorder di kanan. Semua warna dari role skema tema.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../theme/theme.dart';
import 'format.dart';

class HeaderSekolah extends StatelessWidget {
  const HeaderSekolah({super.key, required this.data, required this.sekarang});

  final JadwalData data;

  /// Waktu efektif tampilan (sudah termasuk offset simulasi).
  final DateTime sekarang;

  /// Ukuran sisi kotak logo (persegi 1:1), mengikuti HeaderClock
  /// masjid-you. Kelak diisi logo sekolah asli; kini inisial.
  static const double logoSize = 76;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            // Kotak logo 1:1 (placeholder inisial sekolah).
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                data.sekolah.isEmpty ? '?' : data.sekolah[0],
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Nama sekolah + subjudul jadwal.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.sekolah,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.judul} ${data.tahunPelajaran} '
                    '• Jurusan ${data.jurusan}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Jam + tanggal di kapsul Arch (bentuk ukuran natural khas
            // masjid-you; bukan permukaan yang di-stretch).
            Container(
              padding: const EdgeInsets.only(
                top: 16,
                bottom: 10,
                left: 28,
                right: 28,
              ),
              decoration: ShapeDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: const ArchBorder(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatJam(sekarang),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.0,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatTanggal(sekarang),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
