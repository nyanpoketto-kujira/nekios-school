/// "Spotlight Pergantian Jam" (ADR-017, revisi 2026-11-19):
/// tampilan LAYAR PENUH yang tampil 60 detik pertama setiap masuk
/// slot pelajaran baru, menampilkan kelas + mapel + guru jam
/// tersebut untuk SEMUA kelas sekaligus — pengganti visual
/// pemanggilan nama guru lewat suara.
///
/// Kartunya memakai widget yang sama persis dengan kartu "Sedang
/// Berlangsung" di layar utama ([KartuKelasSekarang]): nama panjang
/// mapel tampil utuh membungkus maksimal 2 baris tanpa terpotong,
/// termasuk nama terpanjang (PJOK). Satu halaman menampung
/// 4 kolom × 3 baris = 12 kartu; kelas lebih dari itu berpindah
/// halaman otomatis membagi rata 60 detik.
///
/// Semua keadaan diturunkan murni dari [DisplayStore.spotlight] +
/// jam efektif: tidak ada timer di widget ini.
library;

import 'package:flutter/material.dart';

import '../state/state.dart';
import 'indikator_halaman.dart';
import 'kartu_kelas.dart';
import 'skala_tampilan.dart';
import 'wavy_progress_bar.dart';

/// Kapasitas kartu per halaman spotlight: grid 4 kolom × 3 baris.
const int kKapasitasHalamanSpotlight = 12;

/// Jumlah kolom grid spotlight (mengikuti grid kartu layar utama).
const int kKolomSpotlight = 4;

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
    final tampil = berentri.skip(awal).take(kKapasitasHalamanSpotlight).toList();
    final sisaDetik = KeadaanSpotlight.durasi.inSeconds - berlalu.inSeconds;
    // Baris grid mengikuti isi halaman ini (1–3): sedikit kelas =
    // kartu lebih besar memenuhi layar, bukan mengambang kecil.
    final baris = (tampil.length + kKolomSpotlight - 1) ~/ kKolomSpotlight;
    final jarak = 18 * s;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layar penuh: latar permukaan nyaris pekat menutupi seluruh
        // tampilan utama selama spotlight berjalan.
        ColoredBox(color: cs.surface.withValues(alpha: 0.97)),
        Padding(
          padding: EdgeInsets.fromLTRB(40 * s, 36 * s, 40 * s, 32 * s),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lebarSel =
                        (constraints.maxWidth - (kKolomSpotlight - 1) * jarak) /
                            kKolomSpotlight;
                    final tinggiSel =
                        (constraints.maxHeight - (baris - 1) * jarak) / baris;
                    return GridView.count(
                      crossAxisCount: kKolomSpotlight,
                      mainAxisSpacing: jarak,
                      crossAxisSpacing: jarak,
                      childAspectRatio: lebarSel / tinggiSel,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final kelas in tampil)
                          KartuKelasSekarang(
                            kelas: kelas,
                            entri: sp.slot.entri[kelas.id]!,
                            data: data,
                          ),
                      ],
                    );
                  },
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
      ],
    );
  }
}
