/// Pemutar bel sekolah (ADR-017).
///
/// Store hanya memutuskan berkas mana yang berbunyi dan menerbitkannya
/// lewat `DisplayStore.streamBel`; pemutaran platform tinggal di sini,
/// di belakang antarmuka kecil agar mudah diganti/palsukan di test.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Kontrak pemutar bel: putar satu berkas aset sampai selesai
/// (pemutaran berikutnya memotong yang sedang berjalan).
abstract interface class PemutarBel {
  Future<void> putar(String berkasAset);
}

/// Pemutar bel sungguhan berbasis `audioplayers` — satu pemain untuk
/// semua pengumuman (bel tidak pernah tumpang tindih). Kegagalan
/// platform ditelan + dicatat: display tidak boleh jatuh karena audio.
class PemutarBelAudioplayers implements PemutarBel {
  final AudioPlayer _pemain = AudioPlayer();

  @override
  Future<void> putar(String berkasAset) async {
    try {
      await _pemain.stop();
      await _pemain.play(AssetSource(berkasAset));
    } catch (e) {
      debugPrint('PemutarBel: gagal memutar $berkasAset: $e');
    }
  }
}
