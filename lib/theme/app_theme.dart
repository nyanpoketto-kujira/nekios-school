/// Tema aplikasi nekios-school — disalin pendekatannya UTUH dari
/// masjid-you tv_display (`theme/app_theme.dart`), sesuai koreksi
/// desain nyanpo (ADR-006): satu keluarga Nekios, satu bahasa visual.
///
/// Skema warna dibangkitkan dari seed yang IDENTIK dengan masjid-you
/// (emerald/teal `0xFF006A60`, dark) lewat [ColorScheme.fromSeed];
/// semua warna UI wajib diambil dari role skema — tidak ada lagi peta
/// hex manual. Skala teks juga sama dengan masjid-you.
library;

import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import 'm3_shape_border.dart';

class AppTheme {
  static ThemeData get darkTheme {
    const seedColor = Color(0xFF006A60); // Emerald/Teal seed color for Material You

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      cardTheme: CardThemeData(
        elevation: 2,
        shape: M3ShapeBorder(MaterialShapes.puffy),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.0,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
    );
  }
}
