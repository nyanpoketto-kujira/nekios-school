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
