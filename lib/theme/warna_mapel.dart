/// Warna pill kode mapel (ukuran tetap) — satu-satunya warna non-skema
/// yang diizinkan selain ornamen blob (ADR-006).
///
/// Pill menurunkan pasangan tonal (container gelap + teks terang) dari
/// hue warna identitas kertas mapel (arsitektur §6 — hex kertas mentah
/// tidak dipakai sebagai latar gelap). Derivasi ini dipertahankan dari
/// Fase 3; yang berubah hanya lokasinya (dulu di `lib/ui/tema.dart`
/// bersama peta hex manual yang kini dihapus).
library;

import 'package:flutter/material.dart';

/// Parse warna hex model ("#RRGGBB") menjadi [Color].
Color warnaDariHex(String hex) {
  final bersih = hex.replaceAll('#', '');
  return Color(int.parse('FF$bersih', radix: 16));
}

/// Warna pill kode mapel di kartu kelas: container gelap se-hue dengan
/// warna identitas kertas + teks terang di atasnya.
({Color latar, Color teks}) warnaPillMapel(String hex) {
  final dasar = HSLColor.fromColor(warnaDariHex(hex));
  final latar = dasar
      .withLightness(0.27)
      .withSaturation((dasar.saturation * 0.75).clamp(0.0, 1.0))
      .toColor();
  final teks = dasar
      .withLightness(0.84)
      .withSaturation((dasar.saturation * 0.6).clamp(0.0, 1.0))
      .toColor();
  return (latar: latar, teks: teks);
}
