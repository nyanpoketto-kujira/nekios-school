/// Kontrak sumber data jadwal nekios-school (Fase 2.5).
///
/// Setiap sumber (asset lokal, WebSocket nekios-core, sumber palsu di
/// test) mengimplementasikan interface yang sama: menembakkan
/// [DisplayEvent] lewat [events]. DisplayStore berlangganan stream
/// ini; mengganti sumber tidak mengubah store maupun UI.
library;

import 'events.dart';

abstract interface class ScheduleSource {
  /// Stream event tampilan dari sumber ini.
  Stream<DisplayEvent> get events;

  /// Mulai sumber (memuat data, membuka koneksi, dst.).
  Future<void> start();

  /// Hentikan sumber dan bebaskan resource-nya.
  Future<void> dispose();
}
