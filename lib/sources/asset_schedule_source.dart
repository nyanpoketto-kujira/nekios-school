/// Sumber jadwal dari asset lokal (Fase 2.5) — sumber MVP.
///
/// Memuat `assets/jadwal-tkj.json`, mem-parse-nya menjadi
/// [JadwalData], lalu meng-emit satu [ScheduleReplaced] saat [start].
/// Fungsi pemuat bisa diinjeksi supaya bisa diuji tanpa rootBundle.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/domain.dart';
import 'events.dart';
import 'schedule_source.dart';

/// Fungsi pemuat teks JSON jadwal.
typedef PemuatanJadwal = Future<String> Function();

class AssetScheduleSource implements ScheduleSource {
  AssetScheduleSource({PemuatanJadwal? pemuat, this.jalurAsset = _jalurDefault})
      : _pemuat = pemuat ?? (() => rootBundle.loadString(jalurAsset));

  static const String _jalurDefault = 'assets/jadwal-tkj.json';

  /// Jalur asset yang dimuat bila [pemuat] tidak diberikan.
  final String jalurAsset;

  final PemuatanJadwal _pemuat;
  final StreamController<DisplayEvent> _controller =
      StreamController<DisplayEvent>.broadcast();

  bool _sudahMulai = false;
  bool _sudahDispose = false;

  @override
  Stream<DisplayEvent> get events => _controller.stream;

  /// Muat JSON dan emit satu [ScheduleReplaced]. Memanggil [start]
  /// dua kali tidak meng-emit ulang. Kegagalan memuat/parse diteruskan
  /// sebagai error pada future ini.
  @override
  Future<void> start() async {
    if (_sudahMulai || _sudahDispose) return;
    _sudahMulai = true;
    final teks = await _pemuat();
    final data =
        JadwalData.fromJson(jsonDecode(teks) as Map<String, dynamic>);
    if (!_sudahDispose) {
      _controller.add(ScheduleReplaced(data));
    }
  }

  @override
  Future<void> dispose() async {
    _sudahDispose = true;
    await _controller.close();
  }
}
