/// Indikator halaman rotasi (Fase 3): titik per halaman, halaman
/// aktif memanjang dengan warna primary (pola board Rotasi 1/2).
library;

import 'package:flutter/material.dart';

import 'tema.dart';

class IndikatorHalaman extends StatelessWidget {
  const IndikatorHalaman({
    super.key,
    required this.jumlah,
    required this.aktif,
  });

  final int jumlah;
  final int aktif;

  @override
  Widget build(BuildContext context) {
    if (jumlah <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < jumlah; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == aktif ? 30 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i == aktif
                  ? TemaWarna.primary
                  : TemaWarna.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ],
    );
  }
}
