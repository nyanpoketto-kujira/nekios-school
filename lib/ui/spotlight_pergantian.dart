/// "Floating Spotlight Pergantian Jam" (ADR-017): panel melayang
/// yang tampil 60 detik pertama setiap masuk slot pelajaran baru,
/// menampilkan kelas + mapel + guru jam tersebut untuk SEMUA kelas
/// sekaligus — pengganti visual pemanggilan nama guru lewat suara.
///
/// Semua keadaan diturunkan murni dari [DisplayStore.spotlight] +
/// jam efektif: tidak ada timer di widget ini. Halaman menampung
/// 4×3 = 12 kartu; kelas lebih dari itu berpindah halaman otomatis
/// membagi rata 60 detik (indikator halaman di bawah panel).
library;

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../state/state.dart';
import '../theme/theme.dart';
import 'indikator_halaman.dart';
import 'skala_tampilan.dart';
import 'wavy_progress_bar.dart';

/// Kapasitas kartu per halaman spotlight: grid 4 kolom × 3 baris.
const int kKapasitasHalamanSpotlight = 12;

/// Apakah spotlight harus tampil pada keadaan store saat ini.
/// Dipakai [DisplayScreen] untuk memutuskan mount; widget sendiri
/// juga memeriksanya (bertahan bila dibangun di luar konteks itu).
bool spotlightSedangTampil(DisplayStore store) {
  final sp = store.spotlight;
  final sekarang = store.jamEfektif;
  if (sp == null || sekarang == null) return false;
  final berlalu = sekarang.difference(sp.mulaiEfektif);
  return !berlalu.isNegative && berlalu < KeadaanSpotlight.durasi;
}

/// Indeks halaman spotlight (0-based) untuk [jumlahKelas] kelas pada
/// detik [berlaluDetik] sejak spotlight mulai. 60 detik dibagi rata
/// ke semua halaman; halaman terakhir menahan sampai selesai.
int halamanSpotlight(int jumlahKelas, int berlaluDetik) {
  final halaman = (jumlahKelas + kKapasitasHalamanSpotlight - 1) ~/
      kKapasitasHalamanSpotlight;
  if (halaman <= 1) return 0;
  final durasiPerHalaman =
      (KeadaanSpotlight.durasi.inSeconds + halaman - 1) ~/ halaman;
  final indeks = berlaluDetik ~/ durasiPerHalaman;
  return indeks >= halaman ? halaman - 1 : indeks;
}

class SpotlightPergantian extends StatelessWidget {
  const SpotlightPergantian({super.key, required this.store});

  final DisplayStore store;

  @override
  Widget build(BuildContext context) {
    final sp = store.spotlight;
    final data = store.data;
    final sekarang = store.jamEfektif;
    if (sp == null || data == null || sekarang == null) {
      return const SizedBox.shrink();
    }
    final berlalu = sekarang.difference(sp.mulaiEfektif);
    if (berlalu.isNegative || berlalu >= KeadaanSpotlight.durasi) {
      return const SizedBox.shrink();
    }
    // Kelas yang punya entri di slot ini, urut sesuai master kelas.
    final kelasTerurut = [...data.kelas]
      ..sort((a, b) => a.urutan.compareTo(b.urutan));
    final berentri = [
      for (final k in kelasTerurut)
        if (sp.slot.entri[k.id] != null) k,
    ];
    if (berentri.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = SkalaTampilan.of(context);
    final jumlahHalaman =
        (berentri.length + kKapasitasHalamanSpotlight - 1) ~/
            kKapasitasHalamanSpotlight;
    final halaman = halamanSpotlight(berentri.length, berlalu.inSeconds);
    final awal = halaman * kKapasitasHalamanSpotlight;
    final tampil = berentri.skip(awal).take(kKapasitasHalamanSpotlight);
    final sisaDetik = KeadaanSpotlight.durasi.inSeconds - berlalu.inSeconds;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Peredup konten di belakang panel pada wilayah overlay.
        ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
        Padding(
          padding: EdgeInsets.all(28 * s),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(36 * s),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(44 * s, 32 * s, 44 * s, 28 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        size: 44 * s,
                        color: cs.tertiary,
                      ),
                      SizedBox(width: 20 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pergantian Jam',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Jam Pelajaran ke-${sp.jamKe} • '
                              '${sp.slot.mulai}–${sp.slot.selesai}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.timer_outlined,
                          size: 22 * s,
                          color: cs.onTertiaryContainer,
                        ),
                        label: Text('$sisaDetik detik'),
                        backgroundColor: cs.tertiaryContainer,
                        labelStyle: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  SizedBox(height: 22 * s),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 18 * s,
                      crossAxisSpacing: 18 * s,
                      childAspectRatio: 2.35,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final kelas in tampil)
                          _KartuSpotlight(
                            kelas: kelas,
                            entri: sp.slot.entri[kelas.id]!,
                            data: data,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18 * s),
                  Row(
                    children: [
                      Expanded(
                        child: WavyProgressBar(
                          progress: sisaDetik / KeadaanSpotlight.durasi.inSeconds,
                          activeColor: cs.tertiary,
                          trackColor: cs.tertiary.withValues(alpha: 0.25),
                          height: 22 * s,
                        ),
                      ),
                      if (jumlahHalaman > 1) ...[
                        SizedBox(width: 24 * s),
                        Text(
                          'Halaman ${halaman + 1} dari $jumlahHalaman',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: 16 * s),
                        IndikatorHalaman(
                          jumlah: jumlahHalaman,
                          aktif: halaman,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu kartu kelas pada spotlight: nama kelas + pill kode mapel,
/// nama panjang mapel, nama guru — padat dan seragam antar kartu.
class _KartuSpotlight extends StatelessWidget {
  const _KartuSpotlight({
    required this.kelas,
    required this.entri,
    required this.data,
  });

  final Kelas kelas;
  final Entri entri;
  final JadwalData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = SkalaTampilan.of(context);
    final mapel = data.mapelByKode(entri.mapel);
    final guru = data.guruByKg(entri.kg);
    final pill = warnaPillMapel(mapel?.warna ?? '#888888');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24 * s),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24 * s, 18 * s, 24 * s, 16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kelas.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: pill.latar,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * s,
                      vertical: 5 * s,
                    ),
                    child: Text(
                      entri.mapel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: pill.teks,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * s),
            Text(
              mapel?.namaPanjang ?? entri.mapel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 4 * s),
            Text(
              guru?.nama ?? 'KG ${entri.kg}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
