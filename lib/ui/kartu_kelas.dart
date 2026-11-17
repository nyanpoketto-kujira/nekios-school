/// Kartu kelas "sedang berlangsung" (ADR-006): filled card M3
/// (surfaceContainer, radius 28, koleksi selevel) dengan hierarki
/// headline/subhead/supporting text ala spec Cards — nama kelas +
/// pill kode mapel di atas, nama panjang mapel besar, nama guru + KG
/// di bawah.
///
/// Nama panjang mapel TIDAK boleh terpotong ellipsis: dipakai
/// `FittedBox.scaleDown` satu baris seperti PrayerCardsRow masjid-you
/// — teks menyusut proporsional bila sempit, tidak pernah hilang.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../theme/theme.dart';

class KartuKelasSekarang extends StatelessWidget {
  const KartuKelasSekarang({
    super.key,
    required this.kelas,
    required this.entri,
    required this.data,
  });

  final Kelas kelas;
  final Entri entri;
  final JadwalData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mapel = data.mapelByKode(entri.mapel);
    final guru = data.guruByKg(entri.kg);
    final pill = warnaPillMapel(mapel?.warna ?? '#888888');
    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 0, // filled card: koleksi berbagi elevasi istirahat sama
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kelas.nama,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontSize: 20,
                    ),
                  ),
                ),
                // Pill kode mapel: elemen ukuran tetap — warna tonal
                // identitas kertas diizinkan di sini (ADR-006).
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: pill.latar,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entri.mapel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pill.teks,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mapel?.namaPanjang ?? entri.mapel,
                    softWrap: false,
                    maxLines: 1,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 36,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    guru?.nama ?? 'KG ${entri.kg}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 22,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'KG ${entri.kg}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
