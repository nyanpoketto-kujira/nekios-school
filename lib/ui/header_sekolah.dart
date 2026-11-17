/// Header sekolah (Fase 3): logo inisial + nama sekolah + subjudul
/// jadwal di kiri; jam digital dan tanggal di kanan.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'tema.dart';

class HeaderSekolah extends StatelessWidget {
  const HeaderSekolah({super.key, required this.data, required this.sekarang});

  final JadwalData data;

  /// Waktu efektif tampilan (sudah termasuk offset simulasi).
  final DateTime sekarang;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: TemaWarna.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            data.sekolah.isEmpty ? '?' : data.sekolah[0],
            style: const TextStyle(
              color: TemaWarna.onPrimaryContainer,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.sekolah,
                style: const TextStyle(
                  color: TemaWarna.onSurface,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.judul} ${data.tahunPelajaran} • Jurusan ${data.jurusan}',
                style: const TextStyle(
                  color: TemaWarna.onSurfaceVariant,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatJam(sekarang),
              style: const TextStyle(
                color: TemaWarna.onSurface,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatTanggal(sekarang),
              style: const TextStyle(
                color: TemaWarna.onSurfaceVariant,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
