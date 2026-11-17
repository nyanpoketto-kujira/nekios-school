/// Kartu kelas "sedang berlangsung" (ADR-006): filled card M3
/// (surfaceContainer, radius 28, koleksi selevel) dengan hierarki
/// headline/subhead/supporting text ala spec Cards — nama kelas +
/// pill kode mapel di atas, nama panjang mapel besar, nama guru + KG
/// di bawah.
///
/// Nama panjang mapel memakai ukuran teks TETAP (headlineMedium dari
/// tema) dengan maksimal 2 baris dan wrap — konsisten di semua kartu.
/// Cara lama (FittedBox.scaleDown satu baris) membuat ukuran antar
/// kartu tidak konsisten: nama pendek tampil raksasa, nama panjang
/// menyusut kecil. Tanpa ellipsis dan tanpa FittedBox, nama terpanjang
/// pun (PJOK, 44 karakter) muat 2 baris pada lebar kartu.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../theme/theme.dart';
import 'skala_tampilan.dart';

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
    final s = SkalaTampilan.of(context);
    final mapel = data.mapelByKode(entri.mapel);
    final guru = data.guruByKg(entri.kg);
    final pill = warnaPillMapel(mapel?.warna ?? '#888888');
    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 0, // filled card: koleksi berbagi elevasi istirahat sama
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28 * s),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28 * s, 24 * s, 28 * s, 22 * s),
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
                      fontSize: 20 * s,
                    ),
                  ),
                ),
                // Pill kode mapel: elemen ukuran tetap — warna tonal
                // identitas kertas diizinkan di sini (ADR-006).
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * s,
                    vertical: 8 * s,
                  ),
                  decoration: BoxDecoration(
                    color: pill.latar,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entri.mapel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pill.teks,
                      fontWeight: FontWeight.bold,
                      fontSize: 17 * s,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18 * s),
            // Area nama mapel fleksibel (min-height 0): teks 2 baris
            // berukuran tetap di tengah area ini.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  mapel?.namaPanjang ?? entri.mapel,
                  maxLines: 2,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 24 * s,
                    height: 1.15,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * s),
            Row(
              children: [
                Expanded(
                  child: Text(
                    guru?.nama ?? 'KG ${entri.kg}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 22 * s,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'KG ${entri.kg}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 18 * s,
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
