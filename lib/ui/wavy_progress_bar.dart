/// Wavy progress bar ala Material You — PORTING dari nekios-mosque
/// (masjid-you `apps/tv_display/lib/widgets/prayer_state_overlay.dart`,
/// widget `_WavyProgressBar` + painter `_WavyProgressPainter`, dipakai
/// overlay Azan & Khutbah). Matematika lukisnya identik dengan sumber:
/// track garis lurus redup selebar area, garis aktif gelombang sinus
/// tunggal (λ 52, amplitudo 5, stroke 8) yang berhenti 7 satuan di
/// belakang cursor, dan cursor bar vertikal (tinggi 22) di ujung
/// aktif. Fase gelombang dibaca dari animasi saat paint (repaint
/// listenable, siklus 2800ms) — 60 FPS tanpa rebuild widget.
///
/// PENYIMPANGAN dari sumber (disengaja, lihat ADR-007): sumber
/// menghitung progress sub-detik dari `deadline` vs `DateTime.now()`.
/// Itu TIDAK dipakai di sini karena jam nekios-school bisa disimulasi
/// (event `ClockSimulated` menggeser jam efektif di DisplayStore) —
/// painter tidak boleh membaca jam sistem. Progress di sini berbasis
/// FRAKSI: [progress] 0..1 dari `KeadaanTampilan.progresSlot` yang
/// di-tick 1 detik oleh store. Bar tetap terasa hidup di antara tick
/// karena fase gelombangnya terus mengalir.
///
/// Semua ukuran geometri (tinggi area, λ, amplitudo, stroke, cursor)
/// diskalakan [SkalaTampilan] agar proporsinya sama dengan desain
/// pada viewport TV sebenarnya (faktor 0.5 di 960×540 logis).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'skala_tampilan.dart';

class WavyProgressBar extends StatefulWidget {
  const WavyProgressBar({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    this.height = 30,
  });

  /// Fraksi progres 0..1 (dijepit ke rentang itu saat melukis).
  final double progress;

  /// Warna garis gelombang aktif + cursor.
  final Color activeColor;

  /// Warna garis track latar (biasanya warna isi ber-alpha rendah).
  final Color trackColor;

  /// Tinggi area lukis dalam satuan desain (sebelum faktor
  /// [SkalaTampilan]). Default 30: cukup untuk cursor 22 + stroke,
  /// dengan margin tipis di atas/bawahnya.
  final double height;

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SkalaTampilan.of(context);
    return SizedBox(
      height: widget.height * s,
      child: CustomPaint(
        painter: _WavyProgressPainter(
          animation: _controller,
          progress: widget.progress,
          activeColor: widget.activeColor,
          trackColor: widget.trackColor,
          wavelength: 52 * s,
          amplitude: 5 * s,
          trackStrokeWidth: 4 * s,
          activeStrokeWidth: 8 * s,
          cursorHeight: 22 * s,
          cursorStrokeWidth: 4 * s,
          // Sama seperti sumber: stroke aktif/2 (4) + 3 = 7.
          waveEndOffset: 7 * s,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Melukis **single wavy stroke line** ala media player Material You
/// (bukan liquid fill): track garis redup + garis gelombang sinus
/// aktif + cursor bar vertikal `|` di ujung kanannya.
/// Fase gelombang dibaca langsung dari [animation] saat paint,
/// sehingga animasi 60 FPS berjalan tanpa rebuild widget (hanya
/// repaint). Nilai [progress] adalah fraksi terpakai 0..1 yang
/// diberikan pemanggil (lihat catatan adaptasi di kepala file).
class _WavyProgressPainter extends CustomPainter {
  final Animation<double> animation;
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double wavelength;
  final double amplitude;
  final double trackStrokeWidth;
  final double activeStrokeWidth;
  final double cursorHeight;
  final double cursorStrokeWidth;
  final double waveEndOffset;

  _WavyProgressPainter({
    required this.animation,
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.wavelength,
    required this.amplitude,
    required this.trackStrokeWidth,
    required this.activeStrokeWidth,
    required this.cursorHeight,
    required this.cursorStrokeWidth,
    required this.waveEndOffset,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // Lebar aktif dari fraksi progres pemanggil (dijepit 0..1).
    final activeWidth = size.width * progress.clamp(0.0, 1.0);

    // Track latar belakang (dimmed line) selebar container.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      trackPaint,
    );

    if (activeWidth <= 0) return;

    // Batas akhir gelombang: offset ke kiri sebesar waveEndOffset
    // agar StrokeCap.round berhenti rapi sedikit di belakang garis
    // cursor di x = activeWidth (jarak ekstra agar tidak terlihat
    // menempel).
    final waveEndX = math.max(0.0, activeWidth - waveEndOffset);

    // Garis gelombang aktif: y = centerY + amplitude * sin((x/λ)·2π - phase).
    final phase = animation.value * 2 * math.pi;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeStrokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(0, centerY + amplitude * math.sin(-phase));
    const step = 2.0;
    for (double x = step; x <= waveEndX; x += step) {
      final y = centerY +
          amplitude * math.sin((x / wavelength) * 2 * math.pi - phase);
      path.lineTo(x, y);
    }
    final endY = centerY +
        amplitude * math.sin((waveEndX / wavelength) * 2 * math.pi - phase);
    path.lineTo(waveEndX, endY);
    canvas.drawPath(path, activePaint);

    // Cursor bar vertikal tegak lurus di ujung kanan garis aktif.
    final cursorPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cursorStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(activeWidth, centerY - cursorHeight / 2),
      Offset(activeWidth, centerY + cursorHeight / 2),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.trackStrokeWidth != trackStrokeWidth ||
        oldDelegate.activeStrokeWidth != activeStrokeWidth ||
        oldDelegate.cursorHeight != cursorHeight ||
        oldDelegate.cursorStrokeWidth != cursorStrokeWidth ||
        oldDelegate.waveEndOffset != waveEndOffset;
  }
}
