/// Event-event yang mengubah state tampilan nekios-school (Fase 2.5).
///
/// Semua input ke layar — dari sumber mana pun (asset lokal sekarang,
/// WebSocket nekios-core kelak) — masuk sebagai [DisplayEvent] dan
/// diterapkan oleh `DisplayStore.terima`. UI tidak pernah tahu event
/// berasal dari mana.
library;

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
