/// Token & pola motion Material 3 (ADR-009, diamendemen ADR-011).
///
/// Dua pola dipakai:
///
/// 1. [TransisiHalaman] + [ElemenHalaman] — pergantian halaman
///    rotasi kelas: SATU AnimatedSwitcher per wilayah ter-swap
///    (baris kartu, label kepala kolom timeline, wilayah chip tiap
///    baris timeline) dengan kunci = indeks halaman. Yang di-swap
///    adalah SELURUH isi wilayah, jadi elemen yang bertambah /
///    berkurang jumlahnya (halaman 4→2, 2→4, dst.) TETAP beranimasi
///    masuk dan keluar — menggantikan switcher per-slot ADR-009
///    yang switcher-nya musnah dari tree saat jumlah anak berubah
///    sehingga elemen ekstra hilang seketika tanpa animasi.
///    Tiap elemen membaca animasi switcher yang sama dan bergerak
///    dalam JENDELA CASCADE SEKUENSIAL per indeksnya (lihat
///    [jendelaCascade]): posisi 1 bertukar sampai hampir tuntas,
///    baru posisi 2, dst. — bukan stagger tumpang-tindih.
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

/// Durasi transisi rotasi halaman (ADR-011): 1200ms — diperlambat
/// dari 500ms (ADR-009) agar cascade sekuensial terasa; pada
/// halaman isi 4 tiap elemen kebagian ±340ms gerak.
const Duration durasiRotasiHalaman = Duration(milliseconds: 1200);

/// Durasi fade-through pergantian status (ADR-011: diperlambat
/// dari 400ms pada ADR-009 menjadi 600ms).
const Duration durasiTransisiStatus = Duration(milliseconds: 600);

/// Durasi animasi indikator halaman (ADR-011: disamakan ritmenya,
/// dari 300ms menjadi 500ms, kurva emphasized tetap).
const Duration durasiIndikatorHalaman = Duration(milliseconds: 500);

/// Layout switcher yang menumpuk anak lama & baru memenuhi ruang
/// (untuk sel/panel berbatas tegas: kartu, chip, layout layar).
Widget tumpukanExpand(Widget? anakSekarang, List<Widget> anakSebelumnya) {
  return Stack(
    fit: StackFit.expand,
    children: [...anakSebelumnya, ?anakSekarang],
  );
}

/// Jendela cascade elemen ke-[indeks] dari [jumlah] elemen
/// (ADR-011): jendela antar indeks NYARIS TIDAK tumpang tindih
/// (overlap maksimal ±15% lebar jendela) — elemen bergerak
/// satu-persatu berurutan, bukan serentak.
///
/// Lebar jendela w = 1/(1 + 0,85·(n−1)) — yaitu porsi 1/n
/// ditambah sedikit overlap; langkah antar indeks
/// s = (1 − w)/(n − 1) sehingga jendela terakhir selalu berakhir
/// tepat di 1.0. Untuk n = 1 jendelanya penuh (0–1). Keluar dan
/// masuk pada indeks yang sama berbagi jendela yang sama (lihat
/// [_progresElemen]).
Interval jendelaCascade(int indeks, int jumlah) {
  if (jumlah <= 1) {
    return const Interval(0.0, 1.0, curve: kurvaEmphasizedM3);
  }
  final lebar = 1.0 / (1.0 + 0.85 * (jumlah - 1));
  final langkah = (1.0 - lebar) / (jumlah - 1);
  final mulai = indeks * langkah;
  return Interval(mulai, mulai + lebar, curve: kurvaEmphasizedM3);
}

/// Progres gerak (0 = keadaan halaman lama utuh / elemen baru
/// belum tampil, 1 = elemen tampil penuh) untuk satu elemen dari
/// animasi switcher halaman.
///
/// Animasi elemen MASUK berjalan forward: progres = jendela
/// diterapkan pada nilai animasi. Animasi elemen KELUAR berjalan
/// reverse (controller switcher berjalan mundur): progres
/// dicerminkan terhadap jendela yang sama, sehingga elemen ke-i
/// tuntas keluar tepat saat elemen ke-i halaman baru tuntas
/// masuk — posisi yang sama bertukar dalam jendela yang sama.
double _progresElemen(Animation<double> animasi, Interval jendela) {
  final nilai = animasi.value.clamp(0.0, 1.0);
  if (animasi.status == AnimationStatus.reverse) {
    return 1.0 - jendela.transform(1.0 - nilai);
  }
  return jendela.transform(nilai);
}

/// Ruang lingkup yang membagikan animasi satu entri switcher
/// halaman ke semua [ElemenHalaman] di dalam isi wilayahnya.
/// Tiap entri (halaman lama yang keluar, halaman baru yang masuk)
/// punya ruangnya sendiri dengan animasinya sendiri.
class _RuangAnimasiHalaman extends InheritedWidget {
  const _RuangAnimasiHalaman({required this.animasi, required super.child});

  final Animation<double> animasi;

  static Animation<double>? dari(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_RuangAnimasiHalaman>()
      ?.animasi;

  @override
  bool updateShouldNotify(_RuangAnimasiHalaman oldWidget) =>
      animasi != oldWidget.animasi;
}

/// Switcher LEVEL-HALAMAN untuk satu wilayah ter-swap (ADR-011):
/// [kunci] adalah indeks halaman; saat berubah, SELURUH [child]
/// (isi wilayah halaman itu) diganti sebagai satu kesatuan dan
/// tiap [ElemenHalaman] di dalamnya beranimasi cascade dari
/// animasi switcher ini.
class TransisiHalaman extends StatelessWidget {
  const TransisiHalaman({
    super.key,
    required this.kunci,
    required this.child,
    this.paskan = true,
  });

  /// Indeks halaman (berubah → seluruh isi wilayah bertukar).
  final int kunci;

  /// Isi wilayah untuk halaman ini (baris kartu / baris label /
  /// baris chip), dengan elemen-elemennya dibungkus
  /// [ElemenHalaman].
  final Widget child;

  /// True bila wilayah berbatas tegas (StackFit.expand); false
  /// untuk konteks tinggi tak berbatas (label kepala kolom) agar
  /// switcher memakai layout bawaan yang mengukur anak.
  final bool paskan;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: durasiRotasiHalaman,
      reverseDuration: durasiRotasiHalaman,
      // Kurva switchIn/switchOut bawaan SENGAJA dibiarkan linear:
      // pembentukan kurva terjadi per elemen lewat jendela
      // cascade di ElemenHalaman, bukan di switcher.
      transitionBuilder: (child, animation) =>
          _RuangAnimasiHalaman(animasi: animation, child: child),
      layoutBuilder: paskan
          ? tumpukanExpand
          : AnimatedSwitcher.defaultLayoutBuilder,
      child: KeyedSubtree(key: ValueKey<int>(kunci), child: child),
    );
  }
}

/// Bungkus [child] dengan [TransisiHalaman] berkunci [kunci] bila
/// [kunci] diisi (timeline ikut rotasi); bila null (layout hero —
/// tidak ada rotasi), kembalikan anak apa adanya tanpa switcher.
Widget bungkusHalaman({
  required int? kunci,
  bool paskan = true,
  required Widget child,
}) {
  if (kunci == null) return child;
  return TransisiHalaman(kunci: kunci, paskan: paskan, child: child);
}

/// Satu elemen di dalam wilayah [TransisiHalaman] (kartu kelas,
/// label kolom, atau chip timeline) pada posisi [indeks] dari
/// [jumlah] elemen wilayah itu.
///
/// Membaca animasi switcher halaman dari ruang lingkupnya dan
/// menerapkan jendela cascade indeksnya: fade + geser vertikal
/// halus (masuk dari bawah, keluar turun) + scale 0.97↔1, kurva
/// emphasized M3. Di luar switcher halaman (layout hero), elemen
/// dirender apa adanya tanpa animasi.
class ElemenHalaman extends StatelessWidget {
  const ElemenHalaman({
    super.key,
    required this.indeks,
    required this.jumlah,
    required this.child,
  });

  /// Indeks elemen dalam wilayahnya (0, 1, 2, 3, …).
  final int indeks;

  /// Jumlah elemen dalam wilayah halaman ini.
  final int jumlah;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animasi = _RuangAnimasiHalaman.dari(context);
    if (animasi == null) return child;
    final jendela = jendelaCascade(indeks, jumlah);
    return AnimatedBuilder(
      animation: animasi,
      child: child,
      builder: (context, anak) {
        final t = _progresElemen(animasi, jendela);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: FractionalTranslation(
            // Geser vertikal fraksional terhadap ukuran elemen
            // sendiri (pola SlideTransition): masuk dari bawah,
            // keluar turun.
            translation: Offset(0, (1.0 - t) * 0.10),
            child: Transform.scale(
              scale: 0.97 + 0.03 * t,
              child: anak!,
            ),
          ),
        );
      },
    );
  }
}

/// Fade-through M3 untuk pergantian layout status (durasi
/// [durasiTransisiStatus] di pemanggil): keluar fade out + scale
/// 1→0.98, masuk fade in + scale 1.02→1, kurva emphasized.
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
