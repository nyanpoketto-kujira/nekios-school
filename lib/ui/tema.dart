/// Tema visual nekios-school (Fase 3).
///
/// Skema dark Material 3 tonal dari desain Penpot (seed hijau,
/// Varian J / Rotasi / board Status), di-hardcode sebagai konstanta —
/// belum ada generator skema runtime; satu tempat untuk menggantinya.
library;

import 'package:flutter/material.dart';

abstract final class TemaWarna {
  static const Color latar = Color(0xFF0C130E);
  static const Color surfaceContainerLow = Color(0xFF141C16);
  static const Color surfaceContainer = Color(0xFF19231B);
  static const Color surfaceContainerHigh = Color(0xFF212D24);
  static const Color surfaceContainerHighest = Color(0xFF2C3A30);
  static const Color onSurface = Color(0xFFDFE9DF);
  static const Color onSurfaceVariant = Color(0xFFB9C6BA);
  static const Color primary = Color(0xFF7BD9A8);
  static const Color primaryContainer = Color(0xFF175C33);
  static const Color onPrimaryContainer = Color(0xFFB9F0CD);
  static const Color secondaryContainer = Color(0xFF2C4A38);
  static const Color tertiary = Color(0xFFE3C878);
  static const Color tertiaryContainer = Color(0xFF4C4010);
  static const Color onTertiaryContainer = Color(0xFFF5E5A8);

  /// Kanvas desain yang diskalakan proporsional ke jendela aktual.
  static const Size ukuranKanvas = Size(1920, 1080);
}

/// Parse warna hex model ("#RRGGBB") menjadi [Color].
Color warnaDariHex(String hex) {
  final bersih = hex.replaceAll('#', '');
  return Color(int.parse('FF$bersih', radix: 16));
}

/// Warna pill kode mapel di kartu kelas: container gelap se-hue dengan
/// warna identitas kertas + teks terang di atasnya (arsitektur §6 —
/// hex kertas mentah tidak dipakai sebagai latar gelap).
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
