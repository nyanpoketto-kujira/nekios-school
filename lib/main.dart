/// Titik masuk nekios-school.
///
/// Merakit DisplayStore + dua sumber yang berjalan bersamaan:
/// AssetScheduleSource (jadwal bawaan/default) dan
/// CoreWebSocketSource (kendali remote nekios-core, Fase R1 —
/// ADR-013), lalu memajukan waktu lewat tick berkala 1 detik.
/// UI hanya membaca store.
///
/// Alat verifikasi visual: `--dart-define=SIM_NOW=2026-11-17T09:20:24`
/// membuat tick selalu memakai waktu tetap itu (default mati — lihat
/// ADR-005).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'sources/sources.dart';
import 'state/state.dart';
import 'theme/theme.dart';
import 'ui/ui.dart';

/// Waktu tetap untuk verifikasi visual; kosong = jam sistem.
const String _simNowMentah = String.fromEnvironment('SIM_NOW');

DateTime? get _simNow =>
    _simNowMentah.isEmpty ? null : DateTime.tryParse(_simNowMentah);

/// Aktifkan mode kios TV: fullscreen immersive + layar tidak tidur
/// (Fase 5 — ADR-012; porting pola nekios-mosque tv_display).
///
/// Kegagalan platform TIDAK boleh menggagalkan startup aplikasi:
/// wakelock dibungkus try/catch persis pola aslinya — bila gagal,
/// aplikasi tetap jalan (layar hanya berisiko tidur).
Future<void> aktifkanModeKios() async {
  // Sembunyikan bar sistem: pengalaman TV layar penuh.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));

  // Cegah layar TV tidur di tengah pameran.
  try {
    await WakelockPlus.enable();
  } catch (e) {
    debugPrint('Wakelock enable failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await aktifkanModeKios();
  runApp(const NekiosSchoolApp());
}

class NekiosSchoolApp extends StatefulWidget {
  const NekiosSchoolApp({super.key, this.sumberRemote});

  /// Sumber remote pengganti untuk test. Bawaan (null) memakai
  /// [CoreWebSocketSource] sungguhan; widget test menginjeksi
  /// sumber palsu karena server WebSocket asli (dart:io HttpServer)
  /// tidak bisa hidup di zona FakeAsync testWidgets — perilaku
  /// servernya sendiri diuji di test integrasi sumber.
  final ScheduleSource? sumberRemote;

  @override
  State<NekiosSchoolApp> createState() => _NekiosSchoolAppState();
}

class _NekiosSchoolAppState extends State<NekiosSchoolApp> {
  late final DisplayStore _store;
  late final AssetScheduleSource _sumber;
  late final ScheduleSource _sumberRemote;
  StreamSubscription<DisplayEvent>? _langganan;
  StreamSubscription<DisplayEvent>? _langgananRemote;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _store = DisplayStore();
    _sumber = AssetScheduleSource();
    _langganan = _sumber.events.listen(_store.terima);
    unawaited(_sumber.start());
    // Sumber remote berjalan BERSAMAAN dengan sumber asset (pola
    // multi-source ADR-004): asset mengisi jadwal awal, remote
    // menimpa lewat event yang sama bila ada perintah masuk.
    // start()-nya tidak pernah melempar — gagal bind port hanya
    // mematikan kendali remote, bukan display (ADR-013).
    _sumberRemote =
        widget.sumberRemote ??
        CoreWebSocketSource(penyediaSnapshot: () => _store.snapshotPaket());
    _langgananRemote = _sumberRemote.events.listen(_store.terima);
    unawaited(_sumberRemote.start());
    _store.tick(_sekarang());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _store.tick(_sekarang()),
    );
  }

  DateTime _sekarang() => _simNow ?? DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_langganan?.cancel() ?? Future<void>.value());
    unawaited(_langgananRemote?.cancel() ?? Future<void>.value());
    unawaited(_sumber.dispose());
    unawaited(_sumberRemote.dispose());
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nekios-school',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: DisplayScreen(store: _store),
    );
  }
}
