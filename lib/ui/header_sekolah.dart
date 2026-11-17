/// Header sekolah (ADR-006): Card ala HeaderClock masjid-you —
/// nama/subjudul sekolah di kiri, jam di dalam kapsul ArchBorder di
/// kanan. Logo sekolah OPSIONAL (ADR-008, pola ADR-032 masjid-you):
/// hanya tampil bila [logoBytes] diisi; tanpa logo tidak ada kotak
/// apa pun dan kolom nama mulai mentok kiri. Semua warna dari role
/// skema tema.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../theme/theme.dart';
import 'format.dart';
import 'skala_tampilan.dart';

class HeaderSekolah extends StatelessWidget {
  const HeaderSekolah({
    super.key,
    required this.data,
    required this.sekarang,
    this.logoBytes,
  });

  final JadwalData data;

  /// Waktu efektif tampilan (sudah termasuk offset simulasi).
  final DateTime sekarang;

  /// Bytes gambar logo sekolah (ADR-008), sudah di-decode oleh
  /// pemanggil. `null` = tidak ada logo: header tampil tanpa kotak
  /// logo sama sekali. Bila ada, logo tampil sebagai kotak **1:1**
  /// di kiri dan kolom nama/subjudul bergeser ke kanan.
  final Uint8List? logoBytes;

  /// Ukuran sisi kotak logo (persegi 1:1) saat logo dipasang,
  /// mengikuti HeaderClock masjid-you.
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
            // Logo sekolah (ADR-008): hanya bila pemanggil memasang
            // logo. Kotak 1:1 dengan fit cover (sumber non-persegi
            // di-crop simetris); tanpa logo, baris ini tidak
            // menyumbang apa pun dan tata letak nama/subjudul mulai
            // mentok kiri persis seperti semula.
            if (logoBytes != null) ...[
              ClipRRect(
                key: const Key('header-logo'),
                borderRadius: BorderRadius.circular(14 * s),
                child: Image.memory(
                  logoBytes!,
                  width: logoSize * s,
                  height: logoSize * s,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: logoSize * s,
                    height: logoSize * s,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.school,
                      size: 40 * s,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16 * s),
            ],
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
