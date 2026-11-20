/// Event-event yang mengubah state tampilan nekios-school (Fase 2.5).
///
/// Semua input ke layar — dari sumber mana pun (asset lokal sekarang,
/// WebSocket nekios-core kelak) — masuk sebagai [DisplayEvent] dan
/// diterapkan oleh `DisplayStore.terima`. UI tidak pernah tahu event
/// berasal dari mana.
library;

import 'dart:typed_data';

import '../domain/domain.dart';

/// Kelas dasar tertutup untuk semua event tampilan. `sealed` membuat
/// `switch` di DisplayStore wajib menangani semua varian.
sealed class DisplayEvent {
  const DisplayEvent();
}

/// Data jadwal diganti seluruhnya (muat awal, atau packet jadwal baru
/// dari remote). [data] memakai format yang sama dengan
/// `assets/jadwal-tkj.json` (round-trip JSON, ADR-002).
final class ScheduleReplaced extends DisplayEvent {
  const ScheduleReplaced(this.data);

  final JadwalData data;
}

/// Teks running text / mading diganti.
final class MadingChanged extends DisplayEvent {
  const MadingChanged(this.teks);

  final String teks;
}

/// Jam tampilan disimulasikan: digeser [offset] dari jam sistem.
/// Inilah jalur simulasi bel/jam dari nekios-remote — bukan hack,
/// karena mesin jadwal memang menerima `now` sebagai parameter.
final class ClockSimulated extends DisplayEvent {
  const ClockSimulated(this.offset);

  final Duration offset;
}

/// Simulasi jam dibatalkan; tampilan kembali ke jam sistem.
final class ClockSimulationCleared extends DisplayEvent {
  const ClockSimulationCleared();
}

/// Logo sekolah diganti dari remote (Fase R1, paket `logo.set`).
/// [bytes] adalah byte gambar yang sudah di-decode dari base64;
/// `null` berarti logo dihapus — header kembali tampil tanpa kotak
/// logo (ADR-008). Store meneruskannya apa adanya ke HeaderSekolah.
final class LogoChanged extends DisplayEvent {
  const LogoChanged(this.bytes);

  final Uint8List? bytes;
}

/// Saklar bel sekolah diatur dari remote (paket `audio.konfigurasi`,
/// ADR-017). Store menyimpan nilai baru dan meneruskannya ke
/// penyimpanan persisten lewat callback komposisi aplikasi.
final class BelKonfigurasiChanged extends DisplayEvent {
  const BelKonfigurasiChanged(this.aktif);

  final bool aktif;
}

/// Remote meminta uji suara bel (paket `audio.tes`, ADR-017): putar
/// pengumuman slot yang sedang berjalan. Selalu diputar — juga saat
/// bel nonaktif — karena ini uji manual yang disengaja.
final class TesBelDiminta extends DisplayEvent {
  const TesBelDiminta();
}

/// Status koneksi remote berubah (Fase R1): [terhubung] true saat
/// ada klien WebSocket tersambung ke sumber remote, false saat
/// klien terakhir putus. Diterbitkan sumber remote sendiri dari
/// pengamatannya atas jumlah klien server; store menyimpannya
/// untuk indikator halus di UI.
final class RemoteConnectionChanged extends DisplayEvent {
  const RemoteConnectionChanged(this.terhubung);

  final bool terhubung;
}
