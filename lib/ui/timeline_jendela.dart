/// Jendela timeline (pola Varian J sebagai wireframe, kulit ADR-006):
/// maksimal 5 kartu slot di sekitar posisi sekarang, dengan rel titik
/// status di kiri dan chip 2 baris per kelas (kode mapel tebal + nama
/// pendek guru). Kolom kelas mengikuti halaman rotasi yang tampil.
///
/// Hierarki permukaan memakai tingkat surface container berbasis tone
/// dari skema (spec M3): selesai = container-low (redup), akan datang
/// = container, berikutnya = container, aktif = primaryContainer +
/// border primary 2 (pola kartu aktif masjid-you). Baris adalah
/// permukaan melebar → rounded rectangle radius large (20), bukan
/// bentuk expressive.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';

class TimelineJendela extends StatelessWidget {
  const TimelineJendela({
    super.key,
    required this.data,
    required this.keadaan,
    required this.kelasKolom,
  });

  final JadwalData data;
  final KeadaanTampilan keadaan;

  /// Kelas-kelas yang ditampilkan sebagai kolom (halaman rotasi aktif).
  final List<Kelas> kelasKolom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'JADWAL HARI INI — ${namaHariKapital(keadaan.sekarang)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  fontSize: 19,
                ),
              ),
            ),
            Text(
              'Sel berisi kode mapel • nama guru',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Kepala kolom: WAKTU + nama kelas per kolom chip.
        Row(
          children: [
            const SizedBox(width: 40),
            SizedBox(
              width: 235,
              child: Text(
                'WAKTU',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontSize: 14,
                ),
              ),
            ),
            for (var i = 0; i < kelasKolom.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: Text(
                  kelasKolom[i].nama,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Baris-baris slot mengisi sisa ruang dengan bobot proporsional
        // terhadap tinggi desain Varian J (aktif paling tinggi), supaya
        // tidak pernah meluber pada jendela mana pun.
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < keadaan.jendela.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Expanded(
                  flex: _bobotBaris(keadaan.jendela[i]),
                  child: _BarisSlot(
                    bingkai: keadaan.jendela[i],
                    data: data,
                    kelasKolom: kelasKolom,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bobot tinggi baris mengikuti hierarki Varian J: selesai 62, aktif
/// 136, berikutnya/akan datang 92 (pelajaran) atau 68 (non-pelajaran).
int _bobotBaris(SlotBingkai b) {
  final pelajaran = b.slot.adalahPelajaran;
  return switch (b.keadaan) {
    KeadaanSlot.aktif => 136,
    KeadaanSlot.selesai => 62,
    KeadaanSlot.berikutnya => pelajaran ? 92 : 68,
    KeadaanSlot.akanDatang => pelajaran ? 92 : 68,
  };
}

class _BarisSlot extends StatelessWidget {
  const _BarisSlot({
    required this.bingkai,
    required this.data,
    required this.kelasKolom,
  });

  final SlotBingkai bingkai;
  final JadwalData data;
  final List<Kelas> kelasKolom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keadaanSlot = bingkai.keadaan;
    final warnaKartu = switch (keadaanSlot) {
      KeadaanSlot.aktif => colorScheme.primaryContainer,
      KeadaanSlot.selesai => colorScheme.surfaceContainerLow,
      _ => colorScheme.surfaceContainer,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RelTitik(keadaan: keadaanSlot),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: warnaKartu,
              borderRadius: BorderRadius.circular(20),
              border: keadaanSlot == KeadaanSlot.aktif
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: bingkai.slot.adalahPelajaran
                ? _isiPelajaran(context)
                : _isiNonPelajaran(context),
          ),
        ),
      ],
    );
  }

  Widget _isiPelajaran(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slot = bingkai.slot;
    final aktif = bingkai.keadaan == KeadaanSlot.aktif;
    final labelStatus = switch (bingkai.keadaan) {
      KeadaanSlot.selesai => 'SELESAI',
      KeadaanSlot.aktif => 'SEDANG BERLANGSUNG',
      KeadaanSlot.berikutnya => 'BERIKUTNYA',
      KeadaanSlot.akanDatang => '',
    };
    final warnaWaktu = switch (bingkai.keadaan) {
      KeadaanSlot.aktif => colorScheme.onPrimaryContainer,
      KeadaanSlot.selesai => colorScheme.onSurfaceVariant,
      _ => colorScheme.onSurface,
    };
    final warnaLabel = switch (bingkai.keadaan) {
      KeadaanSlot.aktif => colorScheme.primary,
      KeadaanSlot.berikutnya => colorScheme.tertiary,
      _ => colorScheme.onSurfaceVariant,
    };
    return Row(
      children: [
        SizedBox(
          width: 235,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slot.mulai}–${slot.selesai}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: warnaWaktu,
                  fontWeight: FontWeight.bold,
                  fontSize: aktif ? 28 : 20,
                  height: 1.05,
                ),
              ),
              if (labelStatus.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  labelStatus,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: warnaLabel,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                    fontSize: 12,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (var i = 0; i < kelasKolom.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: _ChipKelas(
              entri: slot.entri[kelasKolom[i].id],
              data: data,
              keadaan: bingkai.keadaan,
            ),
          ),
        ],
      ],
    );
  }

  Widget _isiNonPelajaran(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final slot = bingkai.slot;
    final label = slot.label ??
        switch (slot.tipe) {
          SlotTipe.istirahat => 'ISTIRAHAT',
          SlotTipe.isoma => 'ISOMA',
          SlotTipe.upacara => 'UPACARA',
          SlotTipe.khusus => 'KEGIATAN KHUSUS',
          SlotTipe.pelajaran => '',
        };
    final warnaTeks = switch (bingkai.keadaan) {
      KeadaanSlot.aktif => colorScheme.onPrimaryContainer,
      KeadaanSlot.selesai => colorScheme.onSurfaceVariant,
      _ => colorScheme.onSurface,
    };
    return Center(
      child: Text(
        '$label • ${slot.mulai}–${slot.selesai}',
        style: theme.textTheme.titleLarge?.copyWith(
          color: warnaTeks,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _ChipKelas extends StatelessWidget {
  const _ChipKelas({
    required this.entri,
    required this.data,
    required this.keadaan,
  });

  final Entri? entri;
  final JadwalData data;
  final KeadaanSlot keadaan;

  @override
  Widget build(BuildContext context) {
    if (entri == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final guru = data.guruByKg(entri!.kg);
    final (warnaLatar, warnaKode, warnaGuru) = switch (keadaan) {
      KeadaanSlot.aktif => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      KeadaanSlot.selesai => (
          colorScheme.surfaceContainer,
          colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      KeadaanSlot.berikutnya => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurface,
          colorScheme.onSurfaceVariant,
        ),
      KeadaanSlot.akanDatang => (
          colorScheme.surfaceContainerHigh,
          colorScheme.onSurface,
          colorScheme.onSurfaceVariant,
        ),
    };
    final aktif = keadaan == KeadaanSlot.aktif;
    return Container(
      decoration: BoxDecoration(
        color: warnaLatar,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entri!.mapel,
            style: theme.textTheme.titleLarge?.copyWith(
              color: warnaKode,
              fontWeight: FontWeight.bold,
              fontSize: aktif ? 24 : 19,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            guru != null ? namaPendekGuru(guru) : 'KG ${entri!.kg}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: warnaGuru,
              fontSize: aktif ? 17 : 14,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rel vertikal + titik status di kiri kartu slot.
class _RelTitik extends StatelessWidget {
  const _RelTitik({required this.keadaan});

  final KeadaanSlot keadaan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      child: CustomPaint(
        painter: _RelPainter(
          keadaan,
          garis: colorScheme.surfaceContainerHighest,
          aktif: colorScheme.primary,
          berikutnya: colorScheme.onSurface,
          redup: colorScheme.onSurfaceVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RelPainter extends CustomPainter {
  _RelPainter(
    this.keadaan, {
    required this.garis,
    required this.aktif,
    required this.berikutnya,
    required this.redup,
  });

  final KeadaanSlot keadaan;
  final Color garis;
  final Color aktif;
  final Color berikutnya;
  final Color redup;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cat = Paint()
      ..color = garis
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), cat);

    final tengah = Offset(cx, size.height / 2);
    switch (keadaan) {
      case KeadaanSlot.aktif:
        canvas.drawCircle(
          tengah,
          17,
          Paint()
            ..color = aktif.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(tengah, 10, Paint()..color = aktif);
      case KeadaanSlot.berikutnya:
        canvas.drawCircle(tengah, 7, Paint()..color = berikutnya);
      case KeadaanSlot.akanDatang:
        canvas.drawCircle(tengah, 6, Paint()..color = redup);
      case KeadaanSlot.selesai:
        canvas.drawCircle(
          tengah,
          6,
          Paint()..color = redup.withValues(alpha: 0.6),
        );
    }
  }

  @override
  bool shouldRepaint(_RelPainter oldDelegate) =>
      oldDelegate.keadaan != keadaan ||
      oldDelegate.garis != garis ||
      oldDelegate.aktif != aktif ||
      oldDelegate.berikutnya != berikutnya ||
      oldDelegate.redup != redup;
}
