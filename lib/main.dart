/// Titik masuk nekios-school.
///
/// Merakit DisplayStore + AssetScheduleSource, lalu memajukan waktu
/// lewat tick berkala 1 detik. UI hanya membaca store.
///
/// Alat verifikasi visual: `--dart-define=SIM_NOW=2026-11-17T09:20:24`
/// membuat tick selalu memakai waktu tetap itu (default mati — lihat
/// ADR-005).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'sources/sources.dart';
import 'state/state.dart';
import 'ui/ui.dart';

/// Waktu tetap untuk verifikasi visual; kosong = jam sistem.
const String _simNowMentah = String.fromEnvironment('SIM_NOW');

DateTime? get _simNow =>
    _simNowMentah.isEmpty ? null : DateTime.tryParse(_simNowMentah);

void main() {
  runApp(const NekiosSchoolApp());
}

class NekiosSchoolApp extends StatefulWidget {
  const NekiosSchoolApp({super.key});

  @override
  State<NekiosSchoolApp> createState() => _NekiosSchoolAppState();
}

class _NekiosSchoolAppState extends State<NekiosSchoolApp> {
  late final DisplayStore _store;
  late final AssetScheduleSource _sumber;
  StreamSubscription<DisplayEvent>? _langganan;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _store = DisplayStore();
    _sumber = AssetScheduleSource();
    _langganan = _sumber.events.listen(_store.terima);
    unawaited(_sumber.start());
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
    unawaited(_sumber.dispose());
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nekios-school',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: DisplayScreen(store: _store),
    );
  }
}
