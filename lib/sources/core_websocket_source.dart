/// Sumber kendali remote lewat WebSocket nekios-core (Fase R1).
///
/// Menjalankan [NekiosServer] dari paket `nekios_core` (port bawaan
/// [kNekiosPort] = 8920) dan menerjemahkan paket perintah remote
/// menjadi [DisplayEvent] yang sama dengan sumber lain:
///
/// | Paket              | Event / balasan                              |
/// | ------------------ | -------------------------------------------- |
/// | `schedule.replace` | [ScheduleReplaced] setelah lolos validasi    |
/// |                    | §7; gagal → paket `error`, jadwal lama utuh  |
/// | `mading.set`       | [MadingChanged]                              |
/// | `clock.simulate`   | [ClockSimulated] (ISO absolut → offset)      |
/// | `clock.clear`      | [ClockSimulationCleared]                     |
/// | `logo.set`         | [LogoChanged] (base64; kosong/null = hapus)  |
/// | `ping`             | dibalas `state.snapshot` dari store          |
///
/// Perintah yang berhasil dibalas `ack` lalu `state.snapshot`
/// terbaru (pola interaksi PROTOCOL.md nekios-core §5). Paket yang
/// gagal decode oleh codec TIDAK memutus koneksi: server core
/// mengalirkannya ke stream terpisah; sumber ini cukup menghitung
/// + mencatatnya ([jumlahPaketTidakValid]).
///
/// Gagal mengikat port (mis. sudah dipakai proses lain) TIDAK
/// menjatuhkan display: [start] menelan kegagalannya, menandainya
/// di [gagalBind], dan aplikasi berjalan tanpa kendali remote —
/// sumber asset tetap sumber jadwal (lihat ADR-013).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nekios_core/nekios_core.dart';

import '../domain/domain.dart';
import 'events.dart';
import 'schedule_source.dart';

/// Penyedia payload `state.snapshot` terkini — dihubungkan di
/// komposisi aplikasi ke `DisplayStore.snapshotPaket`, supaya
/// sumber ini tidak perlu tahu bentuk state tampilan.
typedef PenyediaSnapshot = Map<String, dynamic> Function();

class CoreWebSocketSource implements ScheduleSource {
  CoreWebSocketSource({
    this.port = kNekiosPort,
    this.penyediaSnapshot,
    this.intervalCekKoneksi = const Duration(seconds: 1),
  });

  /// Port WebSocket; bawaan protokol [kNekiosPort] (8920). Isi 0
  /// agar sistem memilih port kosong (dipakai test); port hasil
  /// ikatan dibaca lewat [boundPort].
  final int port;

  /// Penyedia snapshot untuk menjawab `ping` dan menyusuli perintah
  /// yang berhasil. Boleh null — snapshot jatuh ke bentuk minimal
  /// "belumSiap" dengan field yang sama.
  final PenyediaSnapshot? penyediaSnapshot;

  /// Jeda pemeriksaan jumlah klien untuk event
  /// [RemoteConnectionChanged] (server core tidak menyediakan
  /// stream sambung/putus, jadi status koneksi diturunkan dari
  /// `clientCount` yang diperiksa berkala).
  final Duration intervalCekKoneksi;

  final StreamController<DisplayEvent> _controller =
      StreamController<DisplayEvent>.broadcast();

  NekiosServer? _server;
  StreamSubscription<PaketMasuk>? _langgananPaket;
  StreamSubscription<PaketTidakValid>? _langgananTidakValid;
  Timer? _timerKoneksi;

  bool _sudahMulai = false;
  bool _sudahDispose = false;
  bool _terhubungTerakhir = false;

  /// True bila server gagal start (mis. port sudah dipakai).
  /// Display tetap berjalan; hanya kendali remote yang absen.
  bool gagalBind = false;

  /// Kegagalan start terakhir, untuk diagnosis.
  Object? galatBind;

  /// Jumlah paket dari klien yang gagal decode codec dan diabaikan.
  int jumlahPaketTidakValid = 0;

  /// Apakah server WebSocket sedang berjalan?
  bool get serverAktif => _server?.isRunning ?? false;

  /// Port tempat server benar-benar terikat (setelah [start]);
  /// sebelum itu, port yang diminta.
  int get boundPort => _server?.boundPort ?? port;

  /// Jumlah klien remote yang sedang tersambung.
  int get jumlahKlien => _server?.clientCount ?? 0;

  @override
  Stream<DisplayEvent> get events => _controller.stream;

  /// Nyalakan server dan mulai menerjemahkan paket. Kegagalan
  /// mengikat port ditelan (lihat [gagalBind]) — fungsi ini tidak
  /// pernah melempar, agar komposisi aplikasi tidak ikut jatuh.
  /// Memanggil dua kali tidak menyalakan server kedua.
  @override
  Future<void> start() async {
    if (_sudahMulai || _sudahDispose) return;
    _sudahMulai = true;
    final server = NekiosServer(port: port);
    _server = server;
    try {
      await server.start();
    } catch (e) {
      gagalBind = true;
      galatBind = e;
      debugPrint(
        'CoreWebSocketSource: server gagal start di port $port: $e — '
        'display lanjut tanpa kendali remote.',
      );
      return;
    }
    // Balapan dengan dispose(): sumber bisa dibuang selagi bind
    // masih berjalan (mis. widget test yang melepas tree sebelum
    // IO selesai). Jangan buat langganan/timer di atas sumber yang
    // sudah mati — matikan server yang baru terikat.
    if (_sudahDispose) {
      await server.stop();
      return;
    }
    _langgananPaket = server.packets.listen(_tanganiPaket);
    _langgananTidakValid = server.invalidPackets.listen(_catatTidakValid);
    _timerKoneksi = Timer.periodic(intervalCekKoneksi, (_) => _cekKoneksi());
  }

  @override
  Future<void> dispose() async {
    if (_sudahDispose) return;
    _sudahDispose = true;
    _timerKoneksi?.cancel();
    await _langgananPaket?.cancel();
    await _langgananTidakValid?.cancel();
    await _server?.stop();
    await _controller.close();
  }

  void _emit(DisplayEvent event) {
    if (!_sudahDispose) _controller.add(event);
  }

  void _catatTidakValid(PaketTidakValid tidakValid) {
    jumlahPaketTidakValid++;
    debugPrint(
      'CoreWebSocketSource: paket tidak valid diabaikan '
      '(${tidakValid.alasan.deskripsi}).',
    );
  }

  void _cekKoneksi() {
    final terhubung = jumlahKlien > 0;
    if (terhubung != _terhubungTerakhir) {
      _terhubungTerakhir = terhubung;
      _emit(RemoteConnectionChanged(terhubung));
    }
  }

  void _tanganiPaket(PaketMasuk masuk) {
    switch (masuk.paket.type) {
      case TipePaket.scheduleReplace:
        _gantiJadwal(masuk);
      case TipePaket.madingSet:
        _gantiMading(masuk);
      case TipePaket.clockSimulate:
        _simulasiJam(masuk);
      case TipePaket.clockClear:
        _emit(const ClockSimulationCleared());
        _balasSukses(masuk);
      case TipePaket.logoSet:
        _gantiLogo(masuk);
      case TipePaket.ping:
        _balasAman(masuk, _paketSnapshot());
      default:
        // Paket arah balasan (ack / state.snapshot / error) yang
        // sampai ke display: valid secara bentuk, tapi bukan
        // perintah — abaikan tanpa balasan (PROTOCOL.md §4).
        debugPrint(
          'CoreWebSocketSource: paket ${masuk.paket.type} bukan '
          'perintah; diabaikan.',
        );
    }
  }

  void _gantiJadwal(PaketMasuk masuk) {
    final payload = masuk.paket.payload;
    if (payload == null) {
      _balasAman(masuk, NekiosPacket.error('Payload jadwal kosong.'));
      return;
    }
    final JadwalData data;
    try {
      data = JadwalData.fromJson(payload);
    } catch (e) {
      _balasAman(masuk, NekiosPacket.error('Format jadwal tidak terbaca: $e'));
      return;
    }
    // Aturan validasi §7 yang sama dengan jalur data lain: jadwal
    // yang tidak lolos DITOLAK — jadwal lama tetap tampil.
    final kesalahan = validasiJadwal(data);
    if (kesalahan.isNotEmpty) {
      _balasAman(
        masuk,
        NekiosPacket.error(
          'Jadwal ditolak (${kesalahan.length} masalah): '
          '${kesalahan.join('; ')}',
        ),
      );
      return;
    }
    _emit(ScheduleReplaced(data));
    _balasSukses(masuk);
  }

  void _gantiMading(PaketMasuk masuk) {
    final teks = masuk.paket.payload?['text'];
    if (teks is! String) {
      _balasAman(
        masuk,
        NekiosPacket.error('Payload mading.set wajib berisi "text" (string).'),
      );
      return;
    }
    _emit(MadingChanged(teks));
    _balasSukses(masuk);
  }

  void _simulasiJam(PaketMasuk masuk) {
    final mentah = masuk.paket.payload?['at'];
    final at = mentah is String ? DateTime.tryParse(mentah) : null;
    if (at == null) {
      _balasAman(
        masuk,
        NekiosPacket.error(
          'Payload clock.simulate wajib berisi "at" (ISO-8601).',
        ),
      );
      return;
    }
    // Event store berbicara offset dari jam sistem (ADR-004);
    // paket berbicara momen absolut — terjemahkan di sini.
    _emit(ClockSimulated(at.difference(DateTime.now())));
    _balasSukses(masuk);
  }

  void _gantiLogo(PaketMasuk masuk) {
    final mentah = masuk.paket.payload?['imageBase64'];
    // String kosong / null / payload absen = hapus logo.
    if (mentah == null || (mentah is String && mentah.trim().isEmpty)) {
      _emit(const LogoChanged(null));
      _balasSukses(masuk);
      return;
    }
    if (mentah is! String) {
      _balasAman(
        masuk,
        NekiosPacket.error(
          'Payload logo.set: "imageBase64" harus string base64.',
        ),
      );
      return;
    }
    try {
      _emit(LogoChanged(base64Decode(mentah)));
    } on FormatException {
      _balasAman(
        masuk,
        NekiosPacket.error('Payload logo.set: base64 tidak valid.'),
      );
      return;
    }
    _balasSukses(masuk);
  }

  /// Balas perintah berhasil: `ack` sekarang, lalu `state.snapshot`
  /// terbaru menyusul satu putaran event-loop kemudian — memberi
  /// kesempatan store menerapkan event yang baru di-emit (pengantaran
  /// stream bersifat async), supaya snapshot tidak basi.
  void _balasSukses(PaketMasuk masuk) {
    _balasAman(masuk, NekiosPacket.ack(ofType: masuk.paket.type));
    unawaited(
      Future<void>.delayed(Duration.zero).then((_) {
        if (!_sudahDispose) _balasAman(masuk, _paketSnapshot());
      }),
    );
  }

  NekiosPacket _paketSnapshot() => NekiosPacket(
    type: TipePaket.stateSnapshot,
    payload:
        penyediaSnapshot?.call() ??
        const {
          'status': 'belumSiap',
          'jamEfektif': null,
          'simulasiAktif': false,
          'mading': '',
          'hasLogo': false,
          'jamKeAktif': null,
          'slotAktif': null,
          'belBerikutnya': null,
          'sisaKeBelDetik': null,
          'jadwal': null,
        },
  );

  /// Kirim balasan tanpa pernah melempar: klien bisa saja sudah
  /// putus di antara paket diterima dan balasan dikirim.
  void _balasAman(PaketMasuk masuk, NekiosPacket paket) {
    try {
      masuk.balas(paket);
    } catch (e) {
      debugPrint('CoreWebSocketSource: balasan ${paket.type} gagal: $e');
    }
  }
}
