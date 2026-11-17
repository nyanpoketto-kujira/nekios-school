/// Faktor skala tampilan responsif (perbaikan overflow 1080p).
///
/// Desain nekios-school ditulis dalam satuan logis untuk kanvas
/// 1920×1080, tetapi panel TV 1080p pada Android TV melaporkan
/// 1920×1080 piksel FISIK pada devicePixelRatio 2.0 — viewport
/// logisnya hanya 960×540. Tanpa penyesuaian, seluruh ukuran desain
/// tampil dua kali lebih besar dan jumlah tinggi tetap meluber
/// (kasus "BOTTOM OVERFLOWED BY 87 PIXELS").
///
/// Widget ini membawa faktor skala proporsional
/// `min(lebar/1920, tinggi/1080)` (dijepit 0.4–1.0) yang dihitung
/// DisplayScreen dari ukuran body sebenarnya; widget-widget layar
/// mengalikan ukuran desainnya (font, padding, tinggi tetap, celah)
/// dengan faktor ini. Layout tetap flex murni — ini BUKAN kanvas
/// FittedBox: tidak ada ukuran layar yang dikunci, susunan tetap
/// header → strip → kartu → progres → timeline → mading, dan pada
/// viewport 1920×1080 logis faktornya tepat 1.0 (desain asli).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class SkalaTampilan extends InheritedWidget {
  const SkalaTampilan({
    super.key,
    required this.skala,
    required super.child,
  });

  /// Faktor skala aktif (1.0 = ukuran desain penuh).
  final double skala;

  /// Hitung faktor dari ukuran viewport logis yang tersedia.
  static double hitung(Size ukuran) {
    if (ukuran.isEmpty) return 1.0;
    final s = math.min(ukuran.width / 1920, ukuran.height / 1080);
    return s.clamp(0.4, 1.0);
  }

  /// Faktor skala untuk [context]; 1.0 bila tidak ada leluhur
  /// (mis. widget diuji/dipakai berdiri sendiri).
  static double of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<SkalaTampilan>();
    return widget?.skala ?? 1.0;
  }

  @override
  bool updateShouldNotify(SkalaTampilan oldWidget) =>
      oldWidget.skala != skala;
}
