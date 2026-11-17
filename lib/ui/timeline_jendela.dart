/// Jendela timeline (Fase 3, pola Varian J): maksimal 5 kartu slot di
/// sekitar posisi sekarang, dengan rel titik status di kiri dan chip
/// 2 baris per kelas (kode mapel tebal + nama pendek guru). Kolom
/// kelas mengikuti halaman rotasi yang sedang tampil.
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import 'format.dart';
import 'tema.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'JADWAL HARI INI — ${namaHariKapital(keadaan.sekarang)}',
                style: const TextStyle(
                  color: TemaWarna.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Text(
              'Sel berisi kode mapel • nama guru',
              style: TextStyle(
                color: TemaWarna.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Kepala kolom: WAKTU + nama kelas per kolom chip.
        Row(
          children: [
            const SizedBox(width: 40),
            const SizedBox(
              width: 235,
              child: Text(
                'WAKTU',
                style: TextStyle(
                  color: TemaWarna.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (var i = 0; i < kelasKolom.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: Text(
                  kelasKolom[i].nama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TemaWarna.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
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
    final slot = bingkai.slot;
    final keadaanSlot = bingkai.keadaan;
    final warnaKartu = switch (keadaanSlot) {
      KeadaanSlot.aktif => TemaWarna.primaryContainer,
      KeadaanSlot.selesai => TemaWarna.surfaceContainerLow,
      _ => TemaWarna.surfaceContainer,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RelTitik(keadaan: keadaanSlot),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: warnaKartu,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: slot.adalahPelajaran
                ? _isiPelajaran(context)
                : _isiNonPelajaran(context),
          ),
        ),
      ],
    );
  }

  Widget _isiPelajaran(BuildContext context) {
    final slot = bingkai.slot;
    final aktif = bingkai.keadaan == KeadaanSlot.aktif;
    final labelStatus = switch (bingkai.keadaan) {
      KeadaanSlot.selesai => 'SELESAI',
      KeadaanSlot.aktif => 'SEDANG BERLANGSUNG',
      KeadaanSlot.berikutnya => 'BERIKUTNYA',
      KeadaanSlot.akanDatang => '',
    };
    final warnaLabel = switch (bingkai.keadaan) {
      KeadaanSlot.aktif => TemaWarna.primary,
      KeadaanSlot.berikutnya => TemaWarna.tertiary,
      _ => TemaWarna.onSurfaceVariant,
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
                style: TextStyle(
                  color: TemaWarna.onSurface,
                  fontSize: aktif ? 29 : 20,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
              if (labelStatus.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  labelStatus,
                  style: TextStyle(
                    color: warnaLabel,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                    height: 1.05,
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
    final slot = bingkai.slot;
    final label = slot.label ??
        switch (slot.tipe) {
          SlotTipe.istirahat => 'ISTIRAHAT',
          SlotTipe.isoma => 'ISOMA',
          SlotTipe.upacara => 'UPACARA',
          SlotTipe.khusus => 'KEGIATAN KHUSUS',
          SlotTipe.pelajaran => '',
        };
    return Center(
      child: Text(
        '$label • ${slot.mulai}–${slot.selesai}',
        style: const TextStyle(
          color: TemaWarna.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
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
    final guru = data.guruByKg(entri!.kg);
    final (warnaLatar, warnaKode, warnaGuru) = switch (keadaan) {
      KeadaanSlot.aktif => (
          TemaWarna.secondaryContainer,
          TemaWarna.onPrimaryContainer,
          TemaWarna.onPrimaryContainer,
        ),
      KeadaanSlot.selesai => (
          TemaWarna.surfaceContainer,
          TemaWarna.onSurfaceVariant.withValues(alpha: 0.65),
          TemaWarna.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      KeadaanSlot.berikutnya => (
          TemaWarna.surfaceContainerHighest,
          TemaWarna.onSurface,
          TemaWarna.onSurfaceVariant,
        ),
      KeadaanSlot.akanDatang => (
          TemaWarna.surfaceContainerHigh,
          TemaWarna.onSurface,
          TemaWarna.onSurfaceVariant,
        ),
    };
    final aktif = keadaan == KeadaanSlot.aktif;
    return Container(
      decoration: BoxDecoration(
        color: warnaLatar,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entri!.mapel,
            style: TextStyle(
              color: warnaKode,
              fontSize: aktif ? 25 : 19,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            guru != null ? namaPendekGuru(guru) : 'KG ${entri!.kg}',
            style: TextStyle(
              color: warnaGuru,
              fontSize: aktif ? 18 : 14,
              height: 1.05,
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
    return SizedBox(
      width: 40,
      child: CustomPaint(
        painter: _RelPainter(keadaan),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RelPainter extends CustomPainter {
  _RelPainter(this.keadaan);

  final KeadaanSlot keadaan;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final garis = Paint()
      ..color = TemaWarna.surfaceContainerHighest
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), garis);

    final tengah = Offset(cx, size.height / 2);
    switch (keadaan) {
      case KeadaanSlot.aktif:
        canvas.drawCircle(
          tengah,
          17,
          Paint()
            ..color = TemaWarna.primary.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(tengah, 10, Paint()..color = TemaWarna.primary);
      case KeadaanSlot.berikutnya:
        canvas.drawCircle(tengah, 7, Paint()..color = TemaWarna.onSurface);
      case KeadaanSlot.akanDatang:
        canvas.drawCircle(
            tengah, 6, Paint()..color = TemaWarna.onSurfaceVariant);
      case KeadaanSlot.selesai:
        canvas.drawCircle(
          tengah,
          6,
          Paint()..color = TemaWarna.onSurfaceVariant.withValues(alpha: 0.6),
        );
    }
  }

  @override
  bool shouldRepaint(_RelPainter oldDelegate) =>
      oldDelegate.keadaan != keadaan;
}
