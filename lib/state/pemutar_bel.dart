/// Pemutar bel sekolah (ADR-017).
///
/// Store hanya memutuskan rangkaian potongan (chunk) mana yang
/// berbunyi dan menerbitkannya lewat `DisplayStore.streamBel`;
/// pemutaran platform tinggal di sini, di belakang antarmuka kecil
/// agar mudah diganti/palsukan di test.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Kontrak pemutar bel: putar satu rangkaian potongan aset
/// berurutan sampai selesai (pemutaran berikutnya memotong yang
/// sedang berjalan).
abstract interface class PemutarBel {
  Future<void> putar(List<String> rangkaian);
}

/// Pemutar bel sungguhan berbasis `audioplayers` — satu pemain untuk
/// semua pengumuman (bel tidak pernah tumpang tindih). Potongan
/// diputar menyambung: potongan berikutnya dimulai dari peristiwa
/// selesai (`onPlayerComplete`) potongan sebelumnya. Kegagalan
/// platform ditelan + dicatat: display tidak boleh jatuh karena
/// audio; potongan yang gagal dilewati ke potongan berikutnya.
class PemutarBelAudioplayers implements PemutarBel {
  final AudioPlayer _pemain = AudioPlayer();
  StreamSubscription<void>? _langgananSelesai;

  /// Penanda generasi rangkaian: rangkaian baru menaikkan angka ini
  /// sehingga peristiwa selesai dari rangkaian lama (yang terpotong)
  /// tidak ikut memajukan rangkaian baru.
  int _generasi = 0;

  @override
  Future<void> putar(List<String> rangkaian) async {
    final generasi = ++_generasi;
    try {
      await _pemain.stop();
      var indeks = 0;
      Future<void> putarBerikut() async {
        if (generasi != _generasi || indeks >= rangkaian.length) return;
        final berkas = rangkaian[indeks++];
        try {
          await _pemain.play(AssetSource(berkas));
        } catch (e) {
          debugPrint('PemutarBel: gagal memutar $berkas: $e');
          await putarBerikut();
        }
      }

      await _langgananSelesai?.cancel();
      _langgananSelesai = _pemain.onPlayerComplete.listen(
        (_) => unawaited(putarBerikut()),
      );
      await putarBerikut();
    } catch (e) {
      debugPrint('PemutarBel: gagal memulai rangkaian: $e');
    }
  }
}
