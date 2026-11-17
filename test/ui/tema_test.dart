import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/theme/theme.dart';

void main() {
  group('AppTheme (ADR-006)', () {
    test('skema = fromSeed identik masjid-you (0xFF006A60, dark)', () {
      final tema = AppTheme.darkTheme;
      final acuan = ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      );
      final skema = tema.colorScheme;
      expect(skema.primary, acuan.primary);
      expect(skema.primaryContainer, acuan.primaryContainer);
      expect(skema.onPrimaryContainer, acuan.onPrimaryContainer);
      expect(skema.secondaryContainer, acuan.secondaryContainer);
      expect(skema.onSecondaryContainer, acuan.onSecondaryContainer);
      expect(skema.tertiaryContainer, acuan.tertiaryContainer);
      expect(skema.onTertiaryContainer, acuan.onTertiaryContainer);
      expect(skema.surfaceContainer, acuan.surfaceContainer);
      expect(skema.surfaceContainerLow, acuan.surfaceContainerLow);
      expect(skema.surfaceContainerHigh, acuan.surfaceContainerHigh);
      expect(skema.surfaceContainerHighest, acuan.surfaceContainerHighest);
      expect(skema.surfaceContainerLowest, acuan.surfaceContainerLowest);
      expect(skema.outlineVariant, acuan.outlineVariant);
      expect(tema.scaffoldBackgroundColor, skema.surfaceContainerLowest);
      expect(tema.useMaterial3, isTrue);
    });

    test('skala teks sama dengan AppTheme masjid-you', () {
      final teks = AppTheme.darkTheme.textTheme;
      expect(teks.displayLarge?.fontSize, 72);
      expect(teks.displayLarge?.fontWeight, FontWeight.w900);
      expect(teks.displayLarge?.letterSpacing, -2.0);
      expect(teks.displayMedium?.fontSize, 48);
      expect(teks.displayMedium?.fontWeight, FontWeight.w800);
      expect(teks.headlineLarge?.fontSize, 32);
      expect(teks.headlineLarge?.fontWeight, FontWeight.w800);
      expect(teks.headlineMedium?.fontSize, 24);
      expect(teks.titleLarge?.fontSize, 20);
      expect(teks.bodyLarge?.fontSize, 18);
      expect(teks.bodyMedium?.fontSize, 16);
    });
  });

  group('warnaPillMapel', () {
    test('menurunkan pasangan tonal: latar gelap, teks terang, hue sama', () {
      final pill = warnaPillMapel('#43A047');
      final hslLatar = HSLColor.fromColor(pill.latar);
      final hslTeks = HSLColor.fromColor(pill.teks);
      expect(hslLatar.lightness, lessThan(0.5));
      expect(hslTeks.lightness, greaterThan(0.5));
      // Hue dipertahankan dari warna identitas kertas (±2 derajat).
      final hueKertas = HSLColor.fromColor(warnaDariHex('#43A047')).hue;
      expect((hslLatar.hue - hueKertas).abs(), lessThan(2));
    });
  });
}
