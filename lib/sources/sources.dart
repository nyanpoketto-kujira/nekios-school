/// Layer sources nekios-school.
///
/// Semua input masuk sebagai event lewat interface sumber yang sama.
/// MVP memakai sumber asset (JSON default); sumber WebSocket
/// nekios-core kelak menembakkan event yang sama tanpa mengubah UI
/// maupun domain. Diisi pada Fase 2.5 — lihat docs/DECISIONS.md
/// ADR-001 dan ADR-004.
library;

export 'asset_schedule_source.dart';
export 'core_websocket_source.dart';
export 'events.dart';
export 'schedule_source.dart';
