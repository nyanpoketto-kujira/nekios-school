# Keputusan Arsitektur (ADR) — nekios-school

## ADR-001: Microrepo Nekios & layering anti-kerja-dua-kali (2026-11-17)

Konteks: nekios-school adalah bagian ekosistem Nekios (microrepo):
`nekios-core` (protokol sync packet + helper WebSocket + model dasar +
utilitas kiosk), `nekios-school` (display TV sekolah), `nekios-remote`
(kontrol via WebSocket: simulasi bel/jam, ganti teks mading,
auto-detect), `nekios-mosque` (masjid-you). Owner semua repo:
nyanpoketto-kujira; civo-studios hanya committer/collaborator.

Keputusan: struktur layer di dalam repo ini —
`domain/` (Dart murni; mesin jadwal menerima `DateTime now` sebagai
parameter), `state/` (satu DisplayStore berisi snapshot: jadwal, teks
mading, offset jam simulasi, status koneksi), `sources/` (semua input
masuk sebagai event lewat interface yang sama; MVP = sumber asset,
nanti = sumber WebSocket nekios-core), `ui/` (hanya membaca state).

Konsekuensi: MVP pameran jalan mandiri dari JSON default, tetapi
menambah sumber WebSocket kelak tidak mengubah UI/domain. Envelope
packet sementara tinggal di layer sources dan bermigrasi ke package
nekios-core saat repo itu lahir (Fase lanjutan setelah MVP).

## ADR-002: Model domain mencerminkan JSON jadwal (2026-11-17)

Model di `lib/domain/models.dart` adalah cerminan persis
`assets/jadwal-tkj.json` (arsitektur data §3–§5) dengan round-trip
`fromJson`/`toJson`, karena format yang sama menjadi payload packet.
Status tampilan tidak disimpan di model; status diturunkan dari jam
oleh mesin jadwal (Fase 2).

## ADR-003: Mesin jadwal murni dengan `now` sebagai parameter (2026-11-17)

`lib/domain/mesin.dart` menurunkan `KeadaanTampilan` (status, slot
aktif, Jam ke-N, progres, countdown bel, jendela timeline 2–1–2,
halaman rotasi) dari `JadwalData` + `DateTime now`. Mesin tidak pernah
membaca jam sistem: simulasi jam/bel dari nekios-remote kelak cukup
mengirim `now` versi simulasi lewat event state. Status upacara dan
khusus dilebur ke `StatusSekolah.khusus` karena pola tampilannya sama
(hero). Jendela timeline mengikuti pola Varian H/J yang dipilih:
maksimal 5 slot (2 sebelum, aktif, 2 sesudah); sebelum masuk = 5 slot
pertama, pulang = 5 slot terakhir.

## ADR-004: DisplayStore + event + sumber data (2026-11-17)

Konteks: UI butuh satu snapshot state yang bisa berasal dari mana
saja (asset lokal sekarang, WebSocket nekios-remote kelak) tanpa UI
tahu sumbernya (ADR-001).

Keputusan:
- Semua input adalah `DisplayEvent` (sealed class di
  `lib/sources/events.dart`): `ScheduleReplaced(JadwalData)`,
  `MadingChanged(String)`, `ClockSimulated(Duration offset)`,
  `ClockSimulationCleared()`. Simulasi jam dari remote adalah event
  offset terhadap jam sistem — bukan jam palsu yang ditimpa — supaya
  membatalkannya cukup meng-nol-kan offset.
- Sumber data mengimplementasikan `ScheduleSource`
  (`Stream<DisplayEvent> events`, `start()`, `dispose()`). MVP:
  `AssetScheduleSource` memuat `assets/jadwal-tkj.json` dan meng-emit
  satu `ScheduleReplaced` saat start; fungsi pemuatnya bisa diinjeksi
  untuk test.
- `DisplayStore` (ChangeNotifier, `lib/state/display_store.dart`)
  menerapkan event lewat `terima(...)` dan memajukan waktu lewat
  `tick(nowSistem)` yang dipanggil berkala oleh lapisan aplikasi;
  `nowEfektif = nowSistem + offsetSimulasi` lalu
  `keadaan = hitungKeadaan(data, nowEfektif)`.
- Kebijakan notify: `terima` selalu `notifyListeners` (event jarang
  dan selalu bermakna). `tick` hanya notify bila snapshot berubah
  pada resolusi detik (status / indeks slot aktif / sisa bel /
  progres) — cukup untuk countdown per detik, dan mencegah rebuild
  saat tick dipanggil lebih rapat daripada perubahan tampilannya.

Konsekuensi: mengganti sumber (mis. WebSocket) = menulis satu kelas
`ScheduleSource` baru; store, mesin, dan UI tidak berubah.

## ADR-005: UI Fase 3 — kanvas 1920×1080, tema konstan, rotasi, SIM_NOW (2026-11-17)

Konteks: layar TV pertama (status Pelajaran) mengikuti board Penpot
"Varian J — Timeline + Chip 2 Baris" + "Rotasi 1/2".

Keputusan:
- Kanvas desain 1920×1080 digambar apa adanya lalu diskalakan
  proporsional (`FittedBox.contain`) ke jendela aktual — satu tata
  letak untuk semua ukuran TV/desktop.
- Skema warna dark M3 dari desain di-hardcode sebagai konstanta di
  `lib/ui/tema.dart` (belum ada generator skema runtime). Pill kode
  mapel menurunkan container gelap dari hue warna identitas kertas
  (arsitektur §6), bukan hex mentah.
- Rotasi halaman kelas tiap 12 detik dengan `AnimatedSwitcher`
  (crossfade) HANYA pada area kartu kelas dan kolom timeline —
  halaman dari `halamanRotasi` (3 kelas/halaman); header, strip bel,
  dan progres slot tidak ikut berotasi karena sama untuk semua kelas.
- Tinggi baris timeline memakai bobot proporsional terhadap tinggi
  desain Varian J (selesai 62 / aktif 136 / berikutnya 92 / istirahat
  68) di dalam `Expanded`, supaya jendela mana pun tidak meluber.
- Status selain Pelajaran tampil sebagai hero sederhana (kata status
  + countdown, pola board Status); poles visual per status = Fase 4.
- Nama pendek guru untuk chip ("Bu Eva", "Pak Yusuf") sementara
  berupa peta kurasi per KG di `lib/ui/format.dart` mengikuti board
  desain, jatuh ke kata pertama nama untuk KG lain.
- Alat verifikasi visual: `--dart-define=SIM_NOW=<ISO8601>` membuat
  tick selalu memakai waktu tetap itu, supaya tampilan emulator bisa
  dibandingkan dengan board desain pada momen yang sama. Default
  mati (jam sistem); ini alat pengembang, bukan fitur pengguna —
  simulasi jam untuk pengguna kelak lewat event `ClockSimulated`.

## ADR-006: Koreksi desain — Penpot = wireframe, bahasa visual = spec M3 + masjid-you (2026-11-18)

Konteks: nyanpo menilai UI Fase 3 "terpaku banget sama desain utama"
— board Penpot disalin mentah sebagai visual final (hex hijau
campuran manual di `lib/ui/tema.dart`, kotak radius kecil, kanvas
1920×1080 dikunci FittedBox). Koreksinya: board Penpot adalah
WIREFRAME (arsitektur informasi), bukan desain visual. Bahasa visual
nekios-school harus bahasa desain masjid-you (nekios-mosque) — "the
real Material You kiosk design" — yang diground-kan ke panduan resmi
Material 3 (m3.material.io: color roles, shape, typography, cards).

Keputusan:
- Tema disalin pendekatannya utuh dari masjid-you tv_display
  (`lib/theme/app_theme.dart`): `ColorScheme.fromSeed` dengan seed
  IDENTIK masjid-you `0xFF006A60` (dark) — warnanya disamakan, bukan
  varian hijau sekolah. Semua warna UI dari role skema (pasangan
  container/on-container yang sah, hierarki 5 tingkat surface
  container berbasis tone). Peta hex manual dihapus.
- Skala teks sama dengan AppTheme masjid-you (displayLarge 72 w900,
  dst.); angka jam/countdown memakai tabular figures.
- Bentuk expressive (MaterialShapes/M3ShapeBorder, diporting dari
  masjid-you bersama paket `material_new_shapes`) HANYA untuk elemen
  ukuran tetap/natural: ornamen blob latar (fix 120–160), kapsul jam
  ArchBorder, chip pill. DILARANG pada permukaan yang bisa melebar —
  polygon terdistorsi saat di-stretch (aturan nyanpo). Permukaan
  melebar (kartu kelas, baris timeline, hero, strip, bar) memakai
  rounded rectangle radius token M3 (large 20 / extra-large 28–32).
  Kartu kelas = filled card surfaceContainer radius 28 (koleksi
  selevel, elevasi istirahat sama); baris timeline aktif =
  primaryContainer + border primary 2 (pola kartu aktif masjid-you).
- Komposisi berlapis ala tv_display: latar surfaceContainerLowest +
  MaterialBlobBackground (porting; repaint via animation, tanpa
  rebuild tree) + konten. Header = Card radius 28 surfaceContainer
  border outlineVariant, kotak logo 1:1, kapsul jam ArchBorder —
  meniru HeaderClock masjid-you.
- Layout RESPONSIF flex menggantikan kanvas FittedBox tetap (ADR-005
  bagian kanvas dinyatakan superseded oleh ADR ini).
- Nama mapel panjang tidak boleh terpotong ellipsis: FittedBox
  scaleDown satu baris seperti PrayerCardsRow masjid-you.
- Pengecualian warna non-skema HANYA: (a) ornamen blob (teal/emerald
  masjid-you ber-alpha), (b) pill kode mapel ukuran tetap memakai
  derivasi tonal dari warna identitas kertas (`warnaPillMapel`).
- Running text mading akhirnya tampil: bar full-width di dasar layar
  di luar padding konten (pola RunningTextBar masjid-you), membaca
  `DisplayStore.mading` (event MadingChanged, Fase 2.5); kosong →
  teks sambutan default. Marquee sederhana: jeda awal, scroll
  berulang.
- Hero status non-Pelajaran digaya ulang ala PrayerStateOverlay:
  display besar, container tonal per status (ISOMA =
  tertiaryContainer, sebelum masuk = primaryContainer, khusus =
  secondaryContainer), countdown tabular, progress tonal.

Konsekuensi: wireframe Penpot (Varian J, Rotasi, board Status) tetap
menjadi acuan isi & susunan — yang diganti hanya kulitnya. Mengganti
seed/tema kelak cukup di satu tempat (`AppTheme`), dan nekios-school
tampil sedarah dengan masjid-you sebagai keluarga Nekios.

## ADR-007: WavyProgressBar — porting dari nekios-mosque (2026-11-18)

Konteks: nyanpo meminta progress bar diganti bar gelombang
("wavey") dan mengingatkan komponennya sudah ada di masjid-you.
Benar: `_WavyProgressBar` + `_WavyProgressPainter` di
`apps/tv_display/lib/widgets/prayer_state_overlay.dart` masjid-you,
dipakai overlay Azan & Khutbah — bar progres khas Material You
(gelombang sinus tunggal ala media player). Melanjutkan pola
ADR-006, komponen keluarga Nekios dipakai bersama, bukan diciptakan
ulang dengan rasa berbeda.

Keputusan:
- Porting menjadi widget publik `WavyProgressBar`
  (`lib/ui/wavy_progress_bar.dart`). Matematika lukis identik
  dengan sumber: track garis lurus redup, garis aktif sinus
  (λ 52, amplitudo 5, stroke aktif 8 / track 4) berhenti 7 satuan
  sebelum cursor bar vertikal (tinggi 22); fase gelombang dari
  AnimationController 2800ms dibaca painter via repaint listenable
  (60 FPS, tanpa rebuild).
- Adaptasi API yang disengaja: sumber menghitung progress sub-detik
  dari `deadline` vs `DateTime.now()` — TIDAK dipakai, karena jam
  nekios-school bisa disimulasi (`ClockSimulated` di DisplayStore)
  dan painter tidak boleh membaca jam sistem. Progress berbasis
  fraksi `progress` 0..1 dari `KeadaanTampilan.progresSlot` (tick
  1 detik dari store); bar tetap hidup antar-tick lewat animasi
  fase gelombangnya.
- Geometri diskalakan `SkalaTampilan` (tinggi area lukis default
  30 satuan desain, λ/amplitudo/stroke/cursor ikut faktor) agar
  proporsinya sama di viewport TV 960×540 logis.
- Pemasangan: (a) ProgressSlot layar Pelajaran — aktif `primary`,
  track `onSurface` alpha 0.35 (meniru track redup overlay azan);
  label progres & sisa bel tidak berubah. (b) HeroStatus — aktif =
  warna on-container hero, track = warna sama alpha 0.35 (pasangan
  tonal yang sah di atas container hero).
- Tinggi area lukis (30) lebih besar dari bar lurus lama (14/12)
  karena amplitudo + cursor butuh ruang vertikal; layout flex
  menyerapnya — test regresi overflow 1920×1080 DPR 1.0 & 2.0
  tetap hijau, ditambah test widget khusus WavyProgressBar
  (fraksi 0 / 0.44 / 1 + clamp di luar rentang).

Konsekuensi: satu-satunya bar progres di nekios-school sekarang
komponen yang sama dengan overlay azan/khutbah nekios-mosque;
perubahan gaya bar kelak cukup dilakukan sejajar di dua repo
(sampai nekios-core lahir dan komponen ini diangkat ke sana).

## ADR-008: Logo opsional tanpa placeholder + strip khusus Pelajaran (2026-11-18)

Konteks: dua koreksi nyanpo setelah melihat redesign live.
(1) Kotak placeholder berisi huruf "S" di HeaderSekolah terlihat
generik ("kayak AI"): tidak ada logo kok dipaksa ada kotak logo.
masjid-you sudah menyelesaikan ini di ADR-032 — HeaderClock hanya
menampilkan kotak logo bila DKM memasang logo; tanpa logo, header
tampil bersih dan nama mulai mentok kiri.
(2) Pada status hero (ISOMA, sebelum masuk, pulang, khusus),
StripStatusBel mengulang persis info hero (nama status, countdown,
bel berikutnya) — fungsi dobel. Pada status Pelajaran strip justru
disukai karena melengkapi kartu + progres, bukan mengulang.

Keputusan:
- Placeholder inisial "S" DIHAPUS total. HeaderSekolah menerima
  parameter opsional `logoBytes` (Uint8List?) meniru HeaderClock
  masjid-you: non-null → kotak logo 1:1 (key 'header-logo', fit
  cover, fallback ikon sekolah bila bytes rusak); null → tidak ada
  kotak apa pun, kolom nama/subjudul mulai mentok kiri.
- DisplayScreen belum mengoper logo (default null). Jalur dari
  state/remote (event + field state seperti `mosqueLogo` di
  masjid-you) adalah fase berikutnya — tidak dibuat sekarang agar
  tidak ada state mati.
- StripStatusBel hanya dirender pada layout Pelajaran. Layout hero:
  header → hero → timeline. Ruang yang bebas diserap hero lewat
  flex (hero:timeline = 4:7, pola yang sama dengan layout
  Pelajaran), bukan SizedBox/tinggi pengganti yang kaku.
- Test disesuaikan: skenario ISOMA kini menegaskan countdown
  '24:36' muncul SEKALI (sebelumnya findsWidgets dari strip+hero),
  chip 'BEL • 12.45' tidak ada, dan StripStatusBel absen di hero
  tetapi hadir di Pelajaran; test baru HeaderSekolah mengunci
  perilaku logo null vs terpasang.

Konsekuensi: header sekolah dan header masjid memakai pola logo
yang sama persis; saat fitur logo sekolah dikerjakan kelak, cukup
mengisi `logoBytes` dari state tanpa mengubah widget header.

## ADR-009: Motion ekspresif M3 — stagger rotasi + fade-through status (2026-11-18)

Konteks: nyanpo menilai transisi layar "kurang expressive" —
pergantian halaman rotasi hanya crossfade polos bawaan
AnimatedSwitcher, dan pergantian status tidak punya transisi sama
sekali (rebuild seketika). Material 3 punya bahasa motion sendiri:
kurva emphasized dan pola fade-through; keluarga Nekios harus
memakainya agar terasa Material You, bukan sekadar berwarna M3.

Keputusan (token di `lib/ui/transisi.dart`):
- Kurva tunggal emphasized M3: `Cubic(0.2, 0.0, 0.0, 1.0)`
  (`kurvaEmphasizedM3`) untuk semua transisi layar.
- Rotasi halaman (500ms): tiap kartu kelas dan tiap kolom timeline
  (label kepala + chip per baris + isi baris non-pelajaran) punya
  switcher sendiri (`TransisiRotasi`) — masuk fade in + geser naik
  (SlideTransition fraksional 0.10) + scale 0.97→1; keluar fade out
  + geser turun + scale →0.97. STAGGER antar item lewat
  `Interval(indeks × 0.12)` (±60ms per langkah: kartu/kolom ke-2
  mulai ±60ms, ke-3 ±120ms). Timeline menerima `kunciHalaman`;
  layout hero (kunci null) tidak memasang switcher kolom.
- Pergantian status (400ms): satu AnimatedSwitcher fade-through di
  titik pergantian layout pada DisplayScreen, kunci per status —
  konten lama fade out + scale 1→0.98, konten baru fade in + scale
  1.02→1. Tick 1 detik tidak memicu transisi (kunci sama).
- Indikator halaman: lebar dot aktif sudah dianimasikan
  AnimatedContainer; kurvanya disamakan ke emphasized M3.
- Yang TIDAK disentuh: fase gelombang WavyProgressBar (ADR-007),
  marquee running text, dan blob background — animasi ambient itu
  sudah hidup dengan mekanismenya sendiri.
- Semua transisi hanya memainkan opacity/translation/scale
  (transform murah) demi performa TV; tidak ada animasi layout
  (ukuran/posisi widget tidak dianimasikan).

Konsekuensi: test rotasi lama tetap berlaku (pump 600ms >
durasi baru 500ms); test baru `transisi_test.dart` mengunci
keberadaan widget transisi baru dan perilaku tengah-transisi.
Mengubah rasa motion kelak cukup di satu file token.
