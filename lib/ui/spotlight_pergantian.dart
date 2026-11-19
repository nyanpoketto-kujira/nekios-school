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
/// 3 kolom × 3 baris = 9 kartu; kelas lebih dari itu berpindah
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

/// Kapasitas kartu per halaman spotlight: grid 3 kolom × 3 baris
/// (diubah dari 4×3 = 12 atas perintah nyanpo 2026-11-19 — layout
/// spotlight menjadi 3x3).
const int kKapasitasHalamanSpotlight = 9;

/// Jumlah kolom maksimum grid spotlight.
const int kKolomSpotlight = 3;

/// Lebar maksimum satu kartu spotlight (px desain, sebelum skala):
/// selebar kartu "Sedang Berlangsung" di layar utama. Grid TIDAK
/// dipaksa memenuhi lebar layar — selebihnya dibiarkan kosong di
/// kiri-kanan dan grid dipusatkan, supaya kartu tidak melebar
/// berlebihan (perintah nyanpo 2026-11-19).
const double kLebarMaksKartuSpotlight = 440;

/// Rasio lebar:tinggi kartu spotlight, mengikuti proporsi kartu
/// layar utama.
const double kAspekKartuSpotlight = 1.45;

/// Jumlah kolom spotlight untuk [jumlah] kartu pada satu halaman:
/// kolom dipilih supaya barisnya tidak lebih dari 3 dan susunannya
/// seimbang — 6 kartu menjadi 2 kolom × 3 baris (bukan 3×2), sesuai
/// layout 3x3. Sampai 3 kartu tampil sebaris penuh.
int kolomSpotlight(int jumlah) {
  if (jumlah <= 3) return jumlah < 1 ? 1 : jumlah;
  final k = (jumlah + 2) ~/ 3;
  return k > kKolomSpotlight ? kKolomSpotlight : k;
}

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
                    final kolom = kolomSpotlight(tampil.length);
                    final baris = (tampil.length + kolom - 1) ~/ kolom;
                    // Ukuran kartu dibatasi selebar kartu layar utama
                    // lalu grid dipusatkan — tidak dipaksa memenuhi
                    // lebar layar. Bila tinggi tidak cukup (halaman
                    // penuh 3 baris), kartu menyusut mengikuti tinggi.
                    var lebarSel =
                        (constraints.maxWidth - (kolom - 1) * jarak) / kolom;
                    final lebarMaks = kLebarMaksKartuSpotlight * s;
                    if (lebarSel > lebarMaks) lebarSel = lebarMaks;
                    var tinggiSel = lebarSel / kAspekKartuSpotlight;
                    final tinggiPerlu =
                        baris * tinggiSel + (baris - 1) * jarak;
                    if (tinggiPerlu > constraints.maxHeight) {
                      tinggiSel =
                          (constraints.maxHeight - (baris - 1) * jarak) /
                              baris;
                      lebarSel = tinggiSel * kAspekKartuSpotlight;
                    }
                    // Grid dikunci ke ukuran hasil hitung di atas:
                    // tanpa ini GridView mengambil lebar penuh yang
                    // tersedia sehingga ukuran sel menyimpang dari
                    // hitungan (baris bawah bisa terpotong viewport).
                    return Center(
                      child: SizedBox(
                        width: kolom * lebarSel + (kolom - 1) * jarak,
                        height: baris * tinggiSel + (baris - 1) * jarak,
                        child: GridView.count(
                          crossAxisCount: kolom,
                          mainAxisSpacing: jarak,
                          crossAxisSpacing: jarak,
                          childAspectRatio: lebarSel / tinggiSel,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final kelas in tampil)
                              KartuKelasSekarang(
                                kelas: kelas,
                                entri: sp.slot.entri[kelas.id]!,
                                data: data,
                              ),
                          ],
                        ),
                      ),
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
