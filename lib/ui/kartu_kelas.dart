/// Kartu kelas "sedang berlangsung" (Fase 3): nama kelas + pill kode
/// mapel di atas, nama panjang mapel besar, nama guru + KG di bawah.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'tema.dart';

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
    final mapel = data.mapelByKode(entri.mapel);
    final guru = data.guruByKg(entri.kg);
    final pill = warnaPillMapel(mapel?.warna ?? '#888888');
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      decoration: BoxDecoration(
        color: TemaWarna.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kelas.nama,
                  style: const TextStyle(
                    color: TemaWarna.onSurfaceVariant,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                decoration: BoxDecoration(
                  color: pill.latar,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entri.mapel,
                  style: TextStyle(
                    color: pill.teks,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mapel?.namaPanjang ?? entri.mapel,
                style: const TextStyle(
                  color: TemaWarna.onSurface,
                  fontSize: 39,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  guru?.nama ?? 'KG ${entri.kg}',
                  style: const TextStyle(
                    color: TemaWarna.onSurface,
                    fontSize: 25,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'KG ${entri.kg}',
                style: const TextStyle(
                  color: TemaWarna.onSurfaceVariant,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
