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

## ADR-010: Paging rotasi adaptif — 4 kelas per halaman (2026-11-18)

Konteks: keputusan nyanpo — bagian jadwal harus menampung 4 kelas
sekali tampil, dan paging-nya tidak boleh kaku terhadap jumlah
kelas. Saat ini datanya 6 kelas TKJ, tetapi saat dipakai penuh
jumlah kelas bisa berubah (bertambah); halaman terakhir yang
berisi sisa tidak boleh tampil kagok. Ini menyempurnakan
wireframe Penpot: board Rotasi 1/2 dulu menggambar 3 kelas per
halaman, tetapi Penpot adalah wireframe (arsitektur informasi),
bukan patokan jumlah (ADR-006).

Keputusan:
- Ukuran halaman menjadi konstanta domain tunggal
  `ukuranHalamanRotasi = 4` di `lib/domain/mesin.dart`;
  `halamanRotasi` memakainya sebagai `perHalaman` bawaan. Untuk
  6 kelas hasilnya 2 halaman isi [4, 2]. Urutan tetap mengikuti
  `Kelas.urutan`.
- Lebar adaptif tanpa kode khusus per jumlah: baris kartu dan
  kolom timeline sama-sama memakai `Expanded` berbobot sama per
  item, sehingga halaman sisa berisi 3, 2, atau 1 kelas membagi
  lebar baris/kolom secara merata dan memenuhi ruang — tidak ada
  kartu yang menyusut ke lebar halaman penuh lalu menyisakan
  ruang kosong, dan tidak ada overflow pada lebar kolom tersempit
  (isi 4) maupun terlebar (isi 1).
- Indikator halaman dan stagger transisi (ADR-009) mengikuti
  hasil paging secara generik — tidak ada angka jumlah halaman
  atau jumlah kartu yang hardcoded di UI. Satu karakteristik
  transisi pada halaman beda panjang: kartu pada slot yang
  persisten antar halaman bertransisi stagger seperti biasa,
  sedangkan slot ekstra milik halaman yang lebih panjang dilepas
  bersama barisnya saat halaman berganti (switcher-nya memang
  tinggal di slot baris itu).

Konsekuensi: test domain mengunci pola bagi untuk total kelas
1, 4, 5, 6, 7, 8 (termasuk sisa 1 dan halaman penuh); test widget
mengunci isi halaman 1 (4 kartu) dan halaman 2 (2 kartu) pada
skenario Selasa 09:20 beserta kesamaan lebar kartu dan baris yang
terisi penuh; regresi overflow 1920×1080 DPR 1.0 & 2.0 memeriksa
kedua halaman. Menambah/mengurangi kelas kelak cukup mengubah
data — paging, lebar, dan indikator menyesuaikan sendiri.

## ADR-011: Transisi halaman cascade sekuensial — semua elemen ter-swap beranimasi (2026-11-18)

Konteks: nyanpo menonton rekaman transisi dan menemukan tiga hal.
(1) Sebagian elemen ter-swap TIDAK beranimasi: pada pindah
halaman 4→2, kartu di slot indeks 2–3 hilang seketika bersama
barisnya — karakteristik yang dicatat ADR-010 — karena switcher
per-slot (ADR-009) musnah dari tree saat jumlah anak Row berubah.
(2) Transisi terlalu cepat (rotasi 500ms, status 400ms) sehingga
geraknya nyaris tak terlihat. (3) Gerak yang diminta adalah
cascade SEKUENSIAL satu-persatu — kartu 1 bertukar sampai hampir
selesai, baru kartu 2, dst. — bukan stagger yang tumpang-tindih
banyak.

Keputusan (token & pola di `lib/ui/transisi.dart`):
- ATURAN: semua elemen yang ter-swap WAJIB beranimasi masuk DAN
  keluar, berapa pun perubahan jumlah elemen antar halaman.
- Pola switcher LEVEL-HALAMAN menggantikan switcher per-slot
  ADR-009 (bagian ADR-009 itu diamendemen): `TransisiHalaman`
  adalah SATU AnimatedSwitcher per wilayah ter-swap dengan kunci
  = indeks halaman — wilayahnya: baris kartu kelas, label kepala
  kolom timeline, dan wilayah chip pada tiap baris timeline. Yang
  di-swap adalah SELURUH isi wilayah; elemen di dalamnya
  (`ElemenHalaman`) membaca animasi switcher yang sama dan
  menerapkan jendela cascade per indeks kolomnya, sehingga kolom
  timeline (label + chip-chipnya) bergerak sebagai unit dengan
  interval yang sama per indeks. Karena wilayahnya yang berganti
  (bukan slot per slot), elemen yang bertambah/berkurang tetap
  beranimasi penuh.
- Cascade sekuensial: jendela per indeks nyaris TIDAK tumpang
  tindih (overlap maksimal ±15% lebar jendela). Untuk n elemen:
  lebar jendela w = 1/(1 + 0,85·(n−1)) — porsi 1/n plus sedikit
  overlap — dan langkah s = (1 − w)/(n − 1); elemen ke-i memakai
  `Interval(i·s, i·s + w)` berkurva emphasized M3. Keluar dan
  masuk pada indeks yang sama BERBAGI jendela yang sama: progres
  elemen keluar dicerminkan terhadap animasi reverse switcher,
  jadi posisi 1 tuntas bertukar dulu, baru posisi 2, dst. Untuk
  n = 1 jendelanya penuh (0–1). Rumus generik terhadap jumlah
  elemen berapa pun.
- Durasi diperlambat: rotasi 500 → **1200ms** (halaman isi 4:
  tiap elemen kebagian ±340ms gerak), fade-through status
  400 → **600ms**, indikator halaman 300 → **500ms** (kurva
  emphasized tetap). Interval rotasi tetap 12 detik.
- Elemen yang TIDAK berubah antar halaman tidak ikut wilayah
  swap: label waktu dan rel timeline (sudah statis sejak
  ADR-009), dan kini juga label baris non-pelajaran
  (ISTIRAHAT/ISOMA/dll. — teksnya sama di semua halaman)
  dikeluarkan dari switcher agar tidak berkedip tiap rotasi.
- Bahasa gerak per elemen tidak berubah dari ADR-009: fade +
  geser vertikal fraksional 0,10 + scale 0,97↔1, kurva emphasized
  M3; hanya opacity/translation/scale yang dimainkan. Yang tidak
  disentuh tetap: fase WavyProgressBar, marquee mading, blob.

Konsekuensi: karakteristik ADR-010 "slot ekstra dilepas bersama
barisnya tanpa animasi keluar" TIDAK berlaku lagi — seluruh isi
wilayah lama beranimasi keluar dan seluruh isi wilayah baru
beranimasi masuk. Test `transisi_test.dart` mengunci: rumus
jendela (mulai 0, berakhir 1, overlap tepat ±15%, n=4 → ±340ms),
koeksistensi penuh di tengah transisi 4→2 (keempat kartu lama +
kedua kartu baru + chip lama & baru sama-sama di tree), dan sifat
sekuensialnya lewat opasitas terukur (pada 250ms: indeks 0 kedua
halaman sedang bertukar 0<t<1, indeks terakhir lama masih 1,
indeks terakhir baru masih 0). Pump test rotasi di test layar
disesuaikan dari 600ms ke 1300ms mengikuti durasi baru.

Addendum ADR-011 (2026-11-18): nyanpo menyetujui cascade kartu,
tetapi jadwal bawah (timeline) masih terasa belum beranimasi
seurut/sejelas kartu. Audit menemukan BUKAN ada elemen timeline
yang bertukar seketika — label kepala kolom dan semua chip sudah
di dalam wilayah swap sejak ADR-011, dan label waktu/rel/label
non-pelajaran memang tidak berubah antar halaman — melainkan
bahasa gerak kartu yang terlalu lemah untuk elemen timeline:

- Geser vertikal elemen adalah FRAKSI 0,10 dari tinggi elemen
  sendiri. Kartu tinggi (±230 satuan) kebagian ±23 satuan dan
  terbaca; label kepala kolom setinggi ±17 satuan cuma bergeser
  ±2 satuan (tak terlihat), chip baris selesai ±6 satuan.
- Latar chip lama/baru di sel yang sama IDENTIK — warna chip
  ditentukan keadaan baris (selesai/aktif/berikutnya), bukan isi
  kelas — jadi dengan geser sekecil itu pertukaran chip terbaca
  sebagai kedip silang teks yang serentak, bukan cascade kolom
  yang bergerak. Scale 0,97 pada chip lebar-pendek juga tak
  terasa.

Keputusan: `ElemenHalaman` mendapat mode gerak DESAIN opsional
(parameter `geserDesain` + `skalaMin` di `lib/ui/transisi.dart`)
— geser vertikal ABSOLUT dalam satuan desain (× SkalaTampilan),
bukan fraksi tinggi elemen. Kartu TIDAK berubah (mode bawaan:
fraksi 0,10, scale 0,97). Elemen timeline memakai: chip
`geserDesain` 30 + `skalaMin` 0,92; label kepala kolom
`geserDesain` 10 + `skalaMin` 0,85. Jendela cascade, durasi
1200ms, dan momen mulai TIDAK berubah — semua switcher wilayah
(kartu, kepala kolom, chip tiap baris) dipicu rebuild rotasi
yang sama dan memakai rumus jendela yang sama, jadi kolom ke-i
timeline bergerak dalam jendela yang sama persis dengan kartu
ke-i, serentak memulainya. Pada t = 1 kedua mode kembali ke
offset 0 / scale 1: tampilan statis akhir identik.

Test `transisi_test.dart` bertambah satu pembuktian khusus
timeline: pada 250ms opasitas kepala kolom indeks 0 SAMA dengan
opasitas chip kolom 0 (±0,02 — satu jendela, satu momen mulai),
chip kolom terakhir lama masih opasitas 1 di baris pertama DAN
terakhir (tidak ada baris yang mulai lebih dulu), chip kolom
terakhir baru masih 0, dan gerak meluncur chip terukur dari
posisi render (chip keluar tenggelam >10 satuan dari posisi
diamnya; chip masuk tiba dari bawah posisi akhirnya).

## ADR-012: Fase 5 finishing — wakelock + immersive fullscreen (2026-11-18)

Konteks: display pameran berjalan tanpa operator di depan TV.
Dua risiko finishing tersisa di `main`: (1) bar sistem Android
bisa tampil dan mengecilkan area konten; (2) layar TV bisa tidur
di tengah pameran. nekios-mosque tv_display sudah menyelesaikan
keduanya sejak lama di `main()`-nya — Fase 5 mem-porting pola
itu persis, seperti porting WavyProgressBar (ADR-007).

Keputusan:
- `lib/main.dart`: `main()` menjadi async —
  `WidgetsFlutterBinding.ensureInitialized()`, lalu
  `aktifkanModeKios()`, lalu `runApp`. Di dalam
  `aktifkanModeKios()`: `SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.immersiveSticky)` (fire-and-forget via
  `unawaited`, idiom file ini; perilaku sama dengan panggilan
  telanjang di tv_display), lalu `WakelockPlus.enable()` di-await
  di dalam try/catch dengan `debugPrint` saat gagal — persis
  pola aslinya. Kegagalan platform TIDAK pernah menggagalkan
  startup: aplikasi tetap jalan, layar hanya berisiko tidur.
- Dependensi `wakelock_plus: ^1.2.8` ditambahkan ke
  pubspec.yaml — constraint yang sama dengan tv_display.
- Aktivasi diekstrak ke fungsi bernama `aktifkanModeKios()`
  (satu-satunya penyesuaian dari pola asli yang inline) agar
  bisa diuji langsung tanpa menjalankan `main()`.
- Hook verifikasi `--dart-define=SIM_NOW` tidak berubah sama
  sekali: tetap dibaca dari environment yang sama dan dipakai
  tick dengan cara yang sama.

Konsekuensi: TV tampil fullscreen tanpa bar sistem dan tidak
tidur selama aplikasi berjalan; tidak ada pengaturan baru dan
tidak ada perubahan perilaku tampilan lain. Test
`test/main_test.dart` mengunci janji mode kios: mock channel
platform + channel Pigeon wakelock membuktikan kedua
pemanggilan benar-benar terjadi (mode immersiveSticky + satu
toggle enable), amplop error Pigeon membuktikan
`aktifkanModeKios()` tetap selesai normal saat wakelock gagal,
dan widget test membuktikan `NekiosSchoolApp` tetap pump
normal. Verifikasi live di emulator (layar tetap bangun, tanpa
bar sistem) menyusul lewat build APK terpisah.

## ADR-013: Fase R1 — sumber remote WebSocket nekios-core (2026-11-18)

Konteks: nekios-core sudah terbit sebagai paket protokol bersama
(envelope + codec anti-throw + `NekiosServer`/`NekiosKlien`,
protokol v1, port 8920, tanpa PIN — lihat `docs/PROTOCOL.md` di
repo nekios-core) dan spike jaringan emulator sudah lulus.
Arsitektur Fase 2.5 (ADR-004) memang menyiapkan slot ini: semua
input masuk sebagai `DisplayEvent` lewat interface
`ScheduleSource`, jadi sumber WebSocket tinggal menembakkan
event yang sama. Fase R1 mengisi slot itu — sisi display dari
kendali remote; aplikasi remote-nya sendiri adalah Fase R2.

Keputusan:
- Dependensi: `nekios_core` sebagai dependensi git HTTPS
  (`https://github.com/nyanpoketto-kujira/nekios-core.git`,
  ref `main`) di pubspec. Repo core PUBLIK, jadi CI GitHub
  Actions bisa me-resolve tanpa kredensial; commit persisnya
  dikunci `resolved-ref` di pubspec.lock.
- `CoreWebSocketSource implements ScheduleSource`
  (`lib/sources/core_websocket_source.dart`) menjalankan
  `NekiosServer` dan menerjemahkan paket → event:
  `schedule.replace` → parse `JadwalData.fromJson` lalu WAJIB
  lolos `validasiJadwal` (aturan §7 dokumen arsitektur, fungsi
  yang sama dengan jalur data lain) → `ScheduleReplaced`;
  `mading.set` → `MadingChanged`; `clock.simulate` →
  `ClockSimulated` (paket membawa momen absolut ISO-8601, event
  membawa offset dari jam sistem — terjemahan terjadi di
  sumber); `clock.clear` → `ClockSimulationCleared`;
  `logo.set` → event BARU `LogoChanged(Uint8List?)` (payload
  `imageBase64`; string kosong/null/payload absen = hapus logo);
  `ping` → dibalas `state.snapshot`.
- Aturan balasan: perintah sukses dibalas `ack` (payload
  `ofType` = tipe perintah) lalu `state.snapshot` terbaru
  menyusul satu putaran event-loop kemudian (pola PROTOCOL.md
  core §5; jeda itu memberi kesempatan store menerapkan event
  yang baru di-emit, karena pengantaran stream async — snapshot
  tidak basi). Perintah gagal (format payload salah, jadwal
  tidak lolos validasi) dibalas `error` berisi alasan, dan
  TIDAK ada event yang di-emit: jadwal lama tetap tampil utuh.
  Paket yang gagal decode oleh codec tidak pernah sampai ke
  sumber sebagai paket — server core mengalirkannya ke stream
  `invalidPackets`; sumber cukup menghitung
  (`jumlahPaketTidakValid`) + mencatat log, koneksi tidak
  putus. Paket arah balasan (`ack`/`state.snapshot`/`error`)
  yang sampai ke display diabaikan tanpa balasan.
- Snapshot dimiliki store: `DisplayStore.snapshotPaket()`
  mengembalikan payload `state.snapshot` — `status` (nama
  StatusSekolah, atau `belumSiap`), `jamEfektif` (ISO-8601,
  sudah termasuk offset simulasi), `simulasiAktif`, `mading`,
  `hasLogo`, `jamKeAktif`, `slotAktif` {mulai, selesai, tipe,
  label}, `belBerikutnya`, `sisaKeBelDetik`, dan ringkasan
  `jadwal` {sekolah, judul, tahunPelajaran, jurusan,
  jumlahKelas, jumlahHari, hariAktif}. Sumber menerimanya
  sebagai callback `PenyediaSnapshot` yang dihubungkan di
  komposisi aplikasi — layer sources tidak tahu bentuk state
  tampilan. Bentuk payload ini kontrak untuk nekios-remote
  (R2) sebagai cermin keadaan display.
- Store menerima dua event baru: `LogoChanged` → field
  `logoBytes`, diteruskan apa adanya ke `HeaderSekolah` di
  kedua layout (jalur ADR-008 akhirnya terisi); dan
  `RemoteConnectionChanged(bool)` → field `remoteTerhubung`.
- Indikator koneksi: titik `tertiary` + label kecil
  "Remote terhubung" (`onSurfaceVariant`) di ujung kanan bar
  mading, HANYA selama ada klien tersambung. Bar mading dipilih
  karena ia bar utilitas full-width di dasar layar yang selalu
  tampil di semua layout — header dan konten utama tidak
  berubah sama sekali, dan indikator terbaca sebagai status,
  bukan konten. Karena `NekiosServer` tidak menyediakan stream
  sambung/putus, status diturunkan dari `clientCount` yang
  diperiksa berkala (bawaan 1 detik) dan diterbitkan sebagai
  `RemoteConnectionChanged` hanya saat berubah.
- Pola gagal-bind: `CoreWebSocketSource.start()` TIDAK pernah
  melempar. Gagal mengikat port (mis. sudah dipakai) ditandai
  `gagalBind`/`galatBind` + log, dan display berjalan normal
  dengan sumber asset saja. Komposisi di `main.dart` menjalankan
  kedua sumber bersamaan: `AssetScheduleSource` tetap sumber
  jadwal awal/default; sumber remote menimpa lewat event yang
  sama. `start()` juga menjaga balapan dispose-saat-bind:
  sumber yang dibuang selagi bind berjalan mematikan servernya
  dan tidak membuat langganan/timer.
- Testabilitas komposisi: `NekiosSchoolApp` menerima parameter
  opsional `sumberRemote` (bawaan: `CoreWebSocketSource`
  sungguhan). Widget test menginjeksi sumber palsu diam karena
  `HttpServer` dart:io tidak bisa hidup di zona FakeAsync
  testWidgets (timer internal `idleTimeout`-nya dianggap bocor
  oleh invariant test) — perilaku server sungguhan diuji di
  test integrasi `test/sources/core_websocket_source_test.dart`
  dengan server di port acak + `NekiosKlien` asli.

Konsekuensi: display kini bisa dikendalikan penuh dari jaringan
lokal (jadwal, mading, simulasi jam, logo) tanpa mengubah UI
maupun domain; R2 tinggal membangun klien remote di atas
kontrak snapshot di atas. Keterbatasan yang disadari:
granularitas indikator koneksi = interval periksa (1 detik);
logo hanya bisa dipasang dari remote (belum ada pemilih logo
lokal); dan sesuai keputusan protokol v1, belum ada
autentikasi — diasumsikan LAN pameran terpercaya.

## ADR-015: Desktop pameran — kios fullscreen Windows/Linux + build CI (2026-11-19)

Konteks: perangkat stand pameran sekolah (23/24 Nov 2026) hanya
bisa Windows atau Linux desktop — bukan Android TV. Audit
2026-11-19 menemukan: runner `windows/` & `linux/` ada tapi masih
template mentah (jendela 1280×720 + title bar), CI hanya
menghasilkan APK, dan mode kios ADR-012 (`SystemChrome`
immersive) tidak berpengaruh di desktop.

Keputusan:

- **Fullscreen desktop lewat `window_manager`** (satu-satunya
  dependensi baru): di `main()`, khusus platform Windows/Linux
  (`adalahPlatformDesktop`), `siapkanJendelaDesktop()` berjalan
  SEBELUM `runApp` — jendela dibuka langsung fullscreen,
  `TitleBarStyle.hidden`, tombol jendela disembunyikan. Android
  tidak berubah sama sekali (jalur immersive + wakelock ADR-012
  tetap). Kegagalan platform ditelan + dicatat (pola ADR-012):
  startup tidak pernah digagalkan urusan jendela.
- **Jalan keluar operator**: home dibungkus `_KiosDesktop` hanya
  di desktop — **F11** mengaktifkan/mematikan fullscreen, **Esc**
  keluar dari fullscreen. Title bar tetap tersembunyi setelah
  keluar fullscreen; menutup aplikasi lewat Alt+F4/taskbar.
  Display tanpa field teks, jadi fokus keyboard aman dipegang
  pembungkus.
- **CI**: workflow diganti nama "Build" dan ditambah dua job
  release mengikuti pola pemicu APK (PR/manual, retensi 14 hari):
  `build-windows` (windows-latest → `flutter build windows
  --release` → artefak `nekios-school-windows-x64.zip` berisi
  bundle Release) dan `build-linux` (ubuntu-latest + dependensi
  GTK dari dokumentasi Flutter → `flutter build linux --release`
  → artefak `nekios-school-linux-x64.tar.gz` berisi bundle).
  Keduanya mendukung `sim_now` seperti job APK.
- **Server WebSocket 8920 tidak berubah**: murni dart:io dari
  nekios-core, lintas platform. Catatan operasional Windows:
  prompt Windows Firewall saat pertama jalan harus disetujui
  (Allow, jaringan Private) agar remote bisa menyambung.

## ADR-016 — Zip Windows portabel: DLL runtime VC++ dibungkus ke bundle

Konteks (2026-11-19): build Windows dari ADR-015 terverifikasi di PC
pameran asli (Windows 10 1803), tetapi awalnya GAGAL jalan — proses
berhenti seketika dengan kode 0xC0000135 (DLL tidak ditemukan)
karena PC itu belum memiliki Visual C++ Redistributable 2015–2022:
aplikasi Flutter Windows bergantung pada `msvcp140.dll`,
`vcruntime140.dll`, dan `vcruntime140_1.dll` yang tidak termasuk
dalam bundle bawaan `flutter build`. Setelah redistributable
dipasang, aplikasi berjalan normal (fullscreen, server 8920,
remote tersambung). PC stand pameran tidak bisa diasumsikan sudah
memiliki redistributable ini.

Keputusan:

- **Job `build-windows` menyalin 3 DLL redist** (`msvcp140.dll`,
  `vcruntime140.dll`, `vcruntime140_1.dll`) dari System32 runner CI
  ke folder bundle Release, bersebelahan dengan `nekios_school.exe`,
  sebelum di-zip. Windows mencari DLL di folder aplikasi lebih dulu
  daripada System32, jadi zip berjalan di PC Windows mana pun tanpa
  memasang redistributable (penyebaran app-local, pola resmi
  Microsoft untuk DLL-DLL redistributable ini).
- **Gagal keras bila DLL tidak ditemukan** di runner — zip yang
  tidak portabel tidak boleh terkirim diam-diam.
- PC yang sudah memasang redistributable tidak terpengaruh: salinan
  app-local dan salinan sistem berasal dari runtime yang sama.

## ADR-017 — Audio Bel statis ter-bundel + Spotlight Pergantian Jam layar penuh

Konteks (2026-11-19, menuju pameran 23 Nov 2026): bel sekolah perlu
berbunyi di display. Rancangan awal (TTS dinamis yang merakit
pengumuman dari potongan suara termasuk nama guru, disinkronkan dari
HP) DIPANGKAS nyanpo demi kualitas + waktu: data suara TTS di HP
tidak bisa dijamin ada/bagus, dan info per-kelas lebih jelas dibaca
daripada didengar. Protokol nekios-core bertambah dua tipe perintah
(`audio.konfigurasi`, `audio.tes`) dan dua field snapshot
(`belAktif`, `belTerakhir`).

Keputusan:

- **Pengumuman bel = 16 berkas MP3 statis ter-bundel** di
  `assets/audio/` (chime menyatu di awal tiap berkas; runtime memutar
  tepat satu berkas per pengumuman — nol perakitan, nol sinkronisasi
  suara, 100% offline). Pemetaan slot→berkas murni di
  `lib/domain/bel.dart`: pelajaran memakai nomor jam ke-N; istirahat/
  ISOMA/upacara berkas tetap; slot khusus dari labelnya (ROHIS/ROKRIS
  → bel rohis; selainnya → bel kegiatan generik); akhir hari → bel
  pulang. Nama berkas adalah kontrak: rekaman manusia boleh menimpa
  berkas yang sama tanpa ubah kode.
- **Deteksi transisi di DisplayStore**: bel diputuskan dari dua
  snapshot keadaan berurutan (masuk slot baru / status menjadi
  pulang). Loncat simulasi jam ikut memicu (jalur demo pameran),
  KECUALI transisi akibat `clock.clear` dan `schedule.replace` —
  keduanya ditelan satu kali lewat penanda, karena bukan momen bel.
  Tick pertama setelah data dimuat tidak pernah berbunyi.
- **Store tidak menyentuh audio**: store menerbitkan nama berkas ke
  `streamBel`; lapisan aplikasi memutarnya lewat antarmuka
  `PemutarBel` (implementasi `audioplayers`, dipilih karena resmi
  mendukung Android/Windows/Linux). Kegagalan platform ditelan.
- **Saklar `belAktif` persisten di display** (shared_preferences,
  kunci `sekolah.belAktif`, bawaan aktif), diatur remote lewat
  `audio.konfigurasi`. Nonaktif = pengumuman diam; `audio.tes` selalu
  berbunyi (uji manual yang disengaja) memainkan pengumuman slot
  berjalan (di luar slot: contoh jam ke-1). Pemutaran tercatat di
  `belTerakhir` dan terkirim di snapshot sebagai bukti bunyi.
- **Pengganti panggil guru = Spotlight Pergantian Jam**: tampilan
  60 detik pertama setiap masuk slot PELAJARAN baru, menampilkan
  Kelas + Mapel + Guru slot itu untuk semua kelas. Grid 4 kolom,
  12 kartu per halaman (dikunci nyanpo); kelas lebih dari 12
  berpindah halaman otomatis membagi rata 60 detik. Semua keadaan
  (tampil/hilang, halaman, sisa waktu) diturunkan murni dari
  `KeadaanSpotlight` (slot + jamKe + mulaiEfektif) dan jam efektif —
  tanpa timer di widget. Spotlight tampil juga saat bel nonaktif
  (visual bukan suara); masuk slot non-pelajaran menghapusnya.
  **Revisi 2026-11-19 (perintah nyanpo, dari bukti rig):** bentuk
  panel melayang diganti LAYAR PENUH menutupi seluruh tampilan, dan
  kartu spotlight memakai widget yang sama persis dengan kartu
  "Sedang Berlangsung" layar utama (`KartuKelasSekarang`) — kartu
  padat khusus spotlight terbukti meluap (overflow piksel font asli)
  dan memotong nama mapel panjang; kartu utama membungkus nama
  mapel utuh maksimal 2 baris tanpa terpotong. Baris grid mengikuti
  isi halaman (1–3) supaya sedikit kelas tampil besar memenuhi
  layar; lebar kartu dibatasi selebar kartu layar utama dan grid
  dipusatkan — tidak dipaksa memenuhi lebar layar — supaya tidak
  melebar berlebihan.
  **Revisi 2026-11-19 sore (perintah nyanpo):** layout grid diubah
  menjadi 3x3 — kapasitas satu halaman 9 kartu (sebelumnya 4 kolom
  × 3 baris = 12) dan grid selalu selebar 3 kolom supaya 9 kelas
  bisa tampil sekaligus; 6 kelas tampil 3 kolom × 2 baris.
  (Sempat keliru diartikan sebagai susunan seimbang 2 kolom × 3
  baris; dikoreksi nyanpo malam yang sama: 3x3 berarti 3 kolom ×
  3 baris.)

## ADR-018 — Build Linux CI memasang GStreamer untuk audioplayers (2026-11-19)

- **Konteks:** PR Audio Bel (ADR-017) menambah dependensi
  `audioplayers`. Build Linux CI gagal di langkah CMake:
  `audioplayers_linux` mewajibkan paket `gstreamer-1.0` lewat
  pkg-config, yang belum dipasang job `build-linux`.
- **Keputusan:** langkah "Install Linux build dependencies" di
  `.github/workflows/build.yml` menambah `libgstreamer1.0-dev` dan
  `libgstreamer-plugins-base1.0-dev`. Konsekuensi sisi target: bundle
  Linux kini menaut pustaka runtime GStreamer — mesin Linux tujuan
  perlu `libgstreamer1.0-0` + `libgstreamer-plugins-base1.0-0`
  (dan plugin pemutar MP3) agar pemutar bel bisa dimuat; build
  Windows dan Android tidak terpengaruh.
