/// Token & pola motion Material 3 (ADR-009).
///
/// Menggantikan crossfade polos AnimatedSwitcher bawaan yang terasa
/// generik. Dua pola dipakai:
///
/// 1. [TransisiRotasi] — pergantian halaman rotasi kelas: item masuk
///    fade in + geser naik + scale 0.97→1, item keluar fade out +
///    geser turun + scale →0.97, dengan STAGGER antar item (~60ms
///    per indeks) lewat [Interval].
/// 2. [transisiFadeThrough] — pergantian layout status
///    (Pelajaran ↔ hero, antar hero): pola fade-through M3, konten
///    lama fade out + scale 1→0.98, konten baru fade in + scale
///    1.02→1.
///
/// Semua kurva memakai emphasized M3 [kurvaEmphasizedM3]; animasi
/// hanya menyentuh opacity/translation/scale (murah di GPU TV).
/// Animasi yang sudah hidup (fase WavyProgressBar, marquee mading,
/// blob) TIDAK diatur di sini.
library;

import 'package:flutter/material.dart';

/// Kurva emphasized Material 3.
const Cubic kurvaEmphasizedM3 = Cubic(0.2, 0.0, 0.0, 1.0);

/// Layout switcher yang menumpuk anak lama & baru memenuhi ruang
/// (untuk sel/panel berbatas tegas: kartu, chip, layout layar).
Widget tumpukanExpand(Widget? anakSekarang, List<Widget> anakSebelumnya) {
  return Stack(
    fit: StackFit.expand,
    children: [...anakSebelumnya, ?anakSekarang],
  );
}

/// Transisi satu item rotasi (kartu kelas / label kolom / chip
/// timeline) dengan stagger berbasis [indeks].
Widget transisiStaggerRotasi(
  Widget child,
  Animation<double> animation,
  int indeks,
) {
  // 60ms per langkah pada durasi total 500ms = interval 0.12.
  final mulai = (indeks * 0.12).clamp(0.0, 0.6);
  final kurva = CurvedAnimation(
    parent: animation,
    curve: Interval(mulai, 1.0, curve: kurvaEmphasizedM3),
  );
  return FadeTransition(
    opacity: kurva,
    child: SlideTransition(
      // Geser vertikal fraksional: masuk dari bawah, keluar turun.
      position: Tween<Offset>(
        begin: const Offset(0, 0.10),
        end: Offset.zero,
      ).animate(kurva),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(kurva),
        child: child,
      ),
    ),
  );
}

/// Switcher per item rotasi: [kunci] berubah tiap halaman (pemicu
/// transisi), [indeks] menentukan tunda stagger item ini.
class TransisiRotasi extends StatelessWidget {
  const TransisiRotasi({
    super.key,
    required this.kunci,
    required this.indeks,
    required this.child,
    this.paskan = true,
  });

  /// Kunci halaman (berubah → transisi jalan).
  final int kunci;

  /// Indeks item dalam halaman (0, 1, 2) untuk stagger.
  final int indeks;

  final Widget child;

  /// True bila sel berbatas tegas (StackFit.expand); false untuk
  /// konteks tinggi tak berbatas (mis. label kepala kolom) agar
  /// switcher memakai layout bawaan yang mengukur anak.
  final bool paskan;

  static const Duration durasi = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: durasi,
      transitionBuilder: (child, animation) =>
          transisiStaggerRotasi(child, animation, indeks),
      layoutBuilder: paskan
          ? (current, previous) => tumpukanExpand(current, previous)
          : AnimatedSwitcher.defaultLayoutBuilder,
      child: KeyedSubtree(key: ValueKey<int>(kunci), child: child),
    );
  }
}

/// Bungkus [anak] dengan [TransisiRotasi] kolom ke-[indeks] bila
/// [kunciHalaman] diisi (timeline ikut rotasi); bila null (layout
/// hero), kembalikan anak apa adanya tanpa switcher.
Widget transisiKolom(
  Widget anak,
  int? kunciHalaman,
  int indeks, {
  bool paskan = true,
}) {
  if (kunciHalaman == null) return anak;
  return TransisiRotasi(
    kunci: kunciHalaman,
    indeks: indeks,
    paskan: paskan,
    child: anak,
  );
}

/// Fade-through M3 untuk pergantian layout status (~400ms di
/// pemanggil): keluar fade out + scale 1→0.98, masuk fade in +
/// scale 1.02→1, kurva emphasized.
Widget transisiFadeThrough(Widget child, Animation<double> animation) {
  // Anak yang keluar dianimasikan controller yang berjalan mundur.
  final keluar = animation.status == AnimationStatus.reverse;
  final kurva = CurvedAnimation(parent: animation, curve: kurvaEmphasizedM3);
  return FadeTransition(
    opacity: kurva,
    child: ScaleTransition(
      scale: (keluar
              ? Tween<double>(begin: 0.98, end: 1.0)
              : Tween<double>(begin: 1.02, end: 1.0))
          .animate(kurva),
      child: child,
    ),
  );
}
