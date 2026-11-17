/// Indikator halaman rotasi (ADR-006): titik per halaman, halaman
/// aktif memanjang dengan warna primary (pola board Rotasi 1/2).
library;

import 'package:flutter/material.dart';

import 'skala_tampilan.dart';
import 'transisi.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final s = SkalaTampilan.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < jumlah; i++) ...[
          if (i > 0) SizedBox(width: 10 * s),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: kurvaEmphasizedM3,
            width: (i == aktif ? 30 : 10) * s,
            height: 10 * s,
            decoration: BoxDecoration(
              color: i == aktif
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5 * s),
            ),
          ),
        ],
      ],
    );
  }
}
