/// Header sekolah (ADR-006): Card ala HeaderClock masjid-you —
/// kotak logo 1:1 + nama/subjudul sekolah di kiri, jam di dalam
/// kapsul ArchBorder di kanan. Semua warna dari role skema tema.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../theme/theme.dart';
import 'format.dart';
import 'skala_tampilan.dart';

class HeaderSekolah extends StatelessWidget {
  const HeaderSekolah({super.key, required this.data, required this.sekarang});

  final JadwalData data;

  /// Waktu efektif tampilan (sudah termasuk offset simulasi).
  final DateTime sekarang;

  /// Ukuran sisi kotak logo (persegi 1:1), mengikuti HeaderClock
  /// masjid-you. Kelak diisi logo sekolah asli; kini inisial.
  static const double logoSize = 76;

  /// Subjudul ringkas yang muat penuh di kolom nama: label semester
  /// dari judul data (tanpa awalan "Jadwal Pembelajaran"), tahun
  /// pelajaran dengan pemisah '/', lalu jurusan. Contoh hasil:
  /// "Semester Ganjil 2026/2027 • Jurusan TKJ".
  String get _subjudul {
    final kata = data.judul.split(' ');
    final labelSemester =
        kata.length > 2 ? kata.sublist(2).join(' ') : data.judul;
    final tahun = data.tahunPelajaran.replaceAll('-', '/');
    return '$labelSemester $tahun • Jurusan ${data.jurusan}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = SkalaTampilan.of(context);

    return Card(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28 * s),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 14 * s),
        child: Row(
          children: [
            // Kotak logo 1:1 (placeholder inisial sekolah).
            Container(
              width: logoSize * s,
              height: logoSize * s,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14 * s),
              ),
              alignment: Alignment.center,
              child: Text(
                data.sekolah.isEmpty ? '?' : data.sekolah[0],
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 36 * s,
                ),
              ),
            ),
            SizedBox(width: 16 * s),
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
                      fontSize: 30 * s,
                    ),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    _subjudul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 18 * s,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16 * s),
            // Jam + tanggal di kapsul Arch (bentuk ukuran natural khas
            // masjid-you; bukan permukaan yang di-stretch).
            Container(
              padding: EdgeInsets.only(
                top: 16 * s,
                bottom: 10 * s,
                left: 28 * s,
                right: 28 * s,
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
                      fontSize: 44 * s,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    formatTanggal(sekarang),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * s,
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
