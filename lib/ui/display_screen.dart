/// Layar utama TV nekios-school (ADR-006).
///
/// Komposisi berlapis ala masjid-you tv_display: latar
/// surfaceContainerLowest + ornamen blob M3 (ukuran tetap) di bawah
/// konten; konten berupa layout flex RESPONSIF (bukan kanvas
/// FittedBox 1920×1080 yang dikunci); bar running text mading
/// full-width menempel di dasar layar, di luar padding konten.
///
/// Ukuran desain diskalakan proporsional ke viewport logis nyata
/// lewat [SkalaTampilan]: panel TV 1080p melaporkan viewport logis
/// 960×540 (DPR 2.0), bukan 1920×1080 — tanpa skala, jumlah tinggi
/// tetap meluber 87px (lihat test regresi display_screen_1080).
///
/// Layar hanya membaca [DisplayStore]: status pelajaran memakai tata
/// letak wireframe Varian J + rotasi kelas; status lain memakai hero.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/domain.dart';
import '../state/state.dart';
import 'header_sekolah.dart';
import 'hero_status.dart';
import 'indikator_halaman.dart';
import 'kartu_kelas.dart';
import 'material_blob_background.dart';
import 'progress_slot.dart';
import 'running_text.dart';
import 'skala_tampilan.dart';
import 'spotlight_pergantian.dart';
import 'strip_status_bel.dart';
import 'timeline_jendela.dart';
import 'transisi.dart';

class DisplayScreen extends StatelessWidget {
  const DisplayScreen({super.key, required this.store});

  final DisplayStore store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Faktor skala dari ukuran body sebenarnya (viewport logis
          // perangkat), dibagikan ke semua widget layar.
          final skala = SkalaTampilan.hitung(constraints.biggest);
          return SkalaTampilan(
            skala: skala,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Lapisan ornamen: blob M3 ukuran tetap melayang pelan
                // di atas latar polos, di bawah semua konten (pola
                // masjid-you). Ornamen memang tidak diskalakan.
                const MaterialBlobBackground(),
                ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    return Column(
                      children: [
                        Expanded(child: _isi(context)),
                        // Bar mading full-width di dasar layar, membaca
                        // teks dari store (event MadingChanged) dan
                        // status koneksi remote (Fase R1).
                        RunningTextMading(
                          teks: store.mading,
                          namaSekolah: store.data?.sekolah,
                          remoteTerhubung: store.remoteTerhubung,
                        ),
                      ],
                    );
                  },
                ),
                // Spotlight Pergantian Jam (ADR-017): tampilan layar
                // penuh 60 detik setiap masuk slot pelajaran baru,
                // menutupi seluruh layar utama selama tampil.
                ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    if (!spotlightSedangTampil(store)) {
                      return const SizedBox.shrink();
                    }
                    return Positioned.fill(
                      child: SpotlightPergantian(store: store),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _isi(BuildContext context) {
    final data = store.data;
    final keadaan = store.keadaan;
    if (data == null || keadaan == null) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'Memuat jadwal…',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    // Pergantian layout Pelajaran ↔ hero (dan antar hero) memakai
    // SATU AnimatedSwitcher fade-through M3 (ADR-009, durasi 600ms
    // per ADR-011) di titik ini: kuncinya dibedakan per status agar
    // pergantian status memicu transisi, sedangkan tick 1 detik
    // (kunci sama) tidak.
    final Widget isi;
    final String kunciIsi;
    if (keadaan.status == StatusSekolah.pelajaran) {
      kunciIsi = 'layout-pelajaran';
      isi = _LayarPelajaran(store: store, data: data, keadaan: keadaan);
    } else {
      kunciIsi = 'layout-hero-${keadaan.status.name}';
      isi = _layoutHero(context, data, keadaan);
    }
    return AnimatedSwitcher(
      duration: durasiTransisiStatus,
      transitionBuilder: transisiFadeThrough,
      layoutBuilder: tumpukanExpand,
      child: KeyedSubtree(key: ValueKey<String>(kunciIsi), child: isi),
    );
  }

  /// Layout status hero: header + hero + timeline statis.
  ///
  /// StripStatusBel SENGAJA tidak dirender di sini (ADR-008):
  /// isinya — nama status, countdown, bel berikutnya — sama persis
  /// dengan yang ditampilkan hero, jadi fungsi dobel. Strip hanya
  /// tampil di layout Pelajaran.
  /// Logo header datang dari store (`logoBytes`, event LogoChanged
  /// dari remote — ADR-008 + ADR-013); tanpa logo, header tampil
  /// persis seperti semula.
  Widget _layoutHero(
    BuildContext context,
    JadwalData data,
    KeadaanTampilan keadaan,
  ) {
    final s = SkalaTampilan.of(context);
    final halaman = halamanRotasi(data.kelas);
    return Padding(
      padding: EdgeInsets.fromLTRB(40 * s, 24 * s, 40 * s, 16 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeaderSekolah(
            data: data,
            sekarang: keadaan.sekarang,
            logoBytes: store.logoBytes,
          ),
          SizedBox(height: 16 * s),
          // Hero menyerap ruang yang dulu dipakai strip lewat flex,
          // berbagi sisa ruang dengan timeline (4:7, sama seperti
          // layout Pelajaran) — tidak ada tinggi pengganti yang kaku.
          Expanded(flex: 4, child: HeroStatus(keadaan: keadaan)),
          SizedBox(height: 16 * s),
          Expanded(
            flex: 7,
            child: TimelineJendela(
              data: data,
              keadaan: keadaan,
              kelasKolom: halaman.first,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayarPelajaran extends StatefulWidget {
  const _LayarPelajaran({
    required this.store,
    required this.data,
    required this.keadaan,
  });

  final DisplayStore store;
  final JadwalData data;
  final KeadaanTampilan keadaan;

  @override
  State<_LayarPelajaran> createState() => _LayarPelajaranState();
}

class _LayarPelajaranState extends State<_LayarPelajaran> {
  static const _durasiRotasi = Duration(seconds: 12);

  Timer? _timerRotasi;
  int _halaman = 0;

  @override
  void initState() {
    super.initState();
    _timerRotasi = Timer.periodic(_durasiRotasi, (_) {
      final jumlah = halamanRotasi(widget.data.kelas).length;
      if (jumlah > 1 && mounted) {
        setState(() => _halaman = (_halaman + 1) % jumlah);
      }
    });
  }

  @override
  void dispose() {
    _timerRotasi?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SkalaTampilan.of(context);
    final data = widget.data;
    final keadaan = widget.keadaan;
    final halaman = halamanRotasi(data.kelas);
    final indeks = _halaman < halaman.length ? _halaman : 0;
    final kelasHalaman = halaman[indeks];
    final slot = keadaan.slotAktif;

    // Baris kartu TANPA tinggi tetap: tingginya datang dari flex
    // Expanded di bawah, berbagi ruang dengan timeline — keduanya
    // bisa menyusut sehingga total tidak pernah meluber.
    //
    // Seluruh isi baris adalah SATU wilayah swap (ADR-011): satu
    // TransisiHalaman mengganti seluruh baris per halaman, dan tiap
    // kartu beranimasi cascade sekuensial lewat ElemenHalaman —
    // termasuk kartu yang jumlahnya bertambah/berkurang antar
    // halaman (4→2 dst.), yang pada pola per-slot ADR-009 hilang
    // seketika karena switcher slotnya musnah dari tree.
    //
    // Lebar juga adaptif (ADR-010): tiap kartu Expanded berbobot
    // sama, jadi halaman sisa (isi 3, 2, atau 1) membagi lebar baris
    // secara merata dan memenuhi baris — tidak ada kartu menyusut
    // ke lebar halaman penuh lalu menyisakan ruang kosong.
    final barisKartu = TransisiHalaman(
      kunci: indeks,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kelasHalaman.length; i++) ...[
            if (i > 0) SizedBox(width: 24 * s),
            Expanded(
              child: ElemenHalaman(
                indeks: i,
                jumlah: kelasHalaman.length,
                child: slot?.entri[kelasHalaman[i].id] != null
                    ? KartuKelasSekarang(
                        kelas: kelasHalaman[i],
                        entri: slot!.entri[kelasHalaman[i].id]!,
                        data: data,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(40 * s, 24 * s, 40 * s, 16 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeaderSekolah(
            data: data,
            sekarang: keadaan.sekarang,
            logoBytes: widget.store.logoBytes,
          ),
          SizedBox(height: 16 * s),
          StripStatusBel(keadaan: keadaan),
          SizedBox(height: 18 * s),
          // Hanya area kartu + kolom timeline yang berotasi; header,
          // strip, dan progres tetap (pola board Rotasi 1/2). Kartu
          // dan timeline berbagi sisa ruang lewat flex (4:7 — timeline
          // lebih besar karena baris terkecilnya tetap harus memuat
          // chip 2 baris + kolom waktu).
          Expanded(flex: 4, child: barisKartu),
          SizedBox(height: 14 * s),
          ProgressSlot(keadaan: keadaan),
          SizedBox(height: 12 * s),
          Expanded(
            flex: 7,
            child: TimelineJendela(
              data: data,
              keadaan: keadaan,
              kelasKolom: kelasHalaman,
              kunciHalaman: indeks,
            ),
          ),
          SizedBox(height: 10 * s),
          IndikatorHalaman(jumlah: halaman.length, aktif: indeks),
        ],
      ),
    );
  }
}
