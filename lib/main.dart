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
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

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

/// Platform desktop yang didukung kios jendela pameran: Windows
/// dan Linux (perangkat stand pameran hanya bisa salah satu dari
/// keduanya — tahap Desktop Pameran, ADR-015). macOS tidak
/// ditargetkan; Android/iOS memakai jalur immersive [SystemChrome]
/// seperti sebelumnya.
bool adalahPlatformDesktop([String? sistemOperasi]) {
  final os = sistemOperasi ?? Platform.operatingSystem;
  return os == 'windows' || os == 'linux';
}

/// Siapkan jendela desktop untuk pameran: fullscreen tanpa title
/// bar sejak aplikasi dibuka.
///
/// [SystemChrome] immersive tidak berpengaruh di desktop, jadi
/// fullscreen diatur lewat window_manager SEBELUM [runApp] —
/// jendela tidak pernah tampil dalam keadaan berjendela biasa.
/// Title bar disembunyikan permanen (termasuk setelah keluar
/// fullscreen) agar tampilan tetap bersih ala TV; jalan keluar
/// fullscreen untuk operator ada di [_KiosDesktop] (Esc/F11).
///
/// Kegagalan platform TIDAK boleh menggagalkan startup (pola
/// ADR-012): semua dibungkus try/catch, aplikasi tetap jalan.
Future<void> siapkanJendelaDesktop() async {
  try {
    await windowManager.ensureInitialized();
    const opsi = WindowOptions(
      size: Size(1280, 720),
      title: 'nekios-school',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      fullScreen: true,
    );
    await windowManager.waitUntilReadyToShow(opsi, () async {
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint('Siapkan jendela desktop gagal: $e');
  }
}

/// Kunci penyimpanan saklar bel (ADR-017).
const String _kunciBelAktif = 'sekolah.belAktif';

/// Baca saklar bel tersimpan; bawaan aktif. Kegagalan baca tidak
/// boleh menggagalkan startup (pola ADR-012) — jatuh ke aktif.
Future<bool> _muatBelAktif() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kunciBelAktif) ?? true;
  } catch (e) {
    debugPrint('Baca saklar bel tersimpan gagal: $e');
    return true;
  }
}

/// Simpan saklar bel; kegagalan ditelan + dicatat (sesi ini tetap
/// berlaku, hanya tidak persisten).
Future<void> _simpanBelAktif(bool aktif) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kunciBelAktif, aktif);
  } catch (e) {
    debugPrint('Simpan saklar bel gagal: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (adalahPlatformDesktop()) {
    await siapkanJendelaDesktop();
  }
  await aktifkanModeKios();
  final belAktif = await _muatBelAktif();
  runApp(
    NekiosSchoolApp(belAktifAwal: belAktif, simpanBelAktif: _simpanBelAktif),
  );
}

class NekiosSchoolApp extends StatefulWidget {
  const NekiosSchoolApp({
    super.key,
    this.sumberRemote,
    this.pemutarBel,
    this.belAktifAwal = true,
    this.simpanBelAktif,
  });

  /// Sumber remote pengganti untuk test. Bawaan (null) memakai
  /// [CoreWebSocketSource] sungguhan; widget test menginjeksi
  /// sumber palsu karena server WebSocket asli (dart:io HttpServer)
  /// tidak bisa hidup di zona FakeAsync testWidgets — perilaku
  /// servernya sendiri diuji di test integrasi sumber.
  final ScheduleSource? sumberRemote;

  /// Pemutar bel pengganti untuk test; bawaan memakai
  /// [PemutarBelAudioplayers] sungguhan.
  final PemutarBel? pemutarBel;

  /// Saklar bel awal (dari penyimpanan persisten di `main`).
  final bool belAktifAwal;

  /// Penulis saklar bel persisten; null = tidak persisten (test).
  final void Function(bool aktif)? simpanBelAktif;

  @override
  State<NekiosSchoolApp> createState() => _NekiosSchoolAppState();
}

class _NekiosSchoolAppState extends State<NekiosSchoolApp> {
  late final DisplayStore _store;
  late final AssetScheduleSource _sumber;
  late final ScheduleSource _sumberRemote;
  late final PemutarBel _pemutarBel;
  StreamSubscription<DisplayEvent>? _langganan;
  StreamSubscription<DisplayEvent>? _langgananRemote;
  StreamSubscription<List<String>>? _langgananBel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _store = DisplayStore(
      belAktifAwal: widget.belAktifAwal,
      simpanBelAktif: widget.simpanBelAktif,
    );
    // Store memutuskan berkas bel; lapisan aplikasi yang memutarnya
    // (ADR-017). Pemutar menelan kegagalannya sendiri.
    _pemutarBel = widget.pemutarBel ?? PemutarBelAudioplayers();
    _langgananBel = _store.streamBel.listen(
      (rangkaian) => unawaited(_pemutarBel.putar(rangkaian)),
    );
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
    // BUILD PAMERAN (branch feat/pameran-galeri-mock — jangan
    // di-merge): teks mading contoh ter-hardcode supaya display
    // stand langsung hidup tanpa perlu remote. Operator tetap bisa
    // menimpanya dari remote lewat mading.set seperti biasa.
    _store.terima(
      const MadingChanged(
        'Selamat datang di Stand Pameran SMKN 1 Ukui • Layar ini '
        'menampilkan jadwal 18 kelas secara langsung — bagian dari '
        'Nekios, sistem display sekolah karya siswa TKJ • Jurusan: '
        'TKJ • TKR • TSM • Akuntansi • Teknik Elektronika • '
        'Terima kasih atas kunjungannya!',
      ),
    );
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
    unawaited(_langgananBel?.cancel() ?? Future<void>.value());
    unawaited(_langganan?.cancel() ?? Future<void>.value());
    unawaited(_langgananRemote?.cancel() ?? Future<void>.value());
    unawaited(_sumber.dispose());
    unawaited(_sumberRemote.dispose());
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layar = DisplayScreen(store: _store);
    return MaterialApp(
      title: 'nekios-school',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Di desktop, display dibungkus jalan keluar fullscreen
      // untuk operator; di Android tampil apa adanya.
      home: adalahPlatformDesktop() ? _KiosDesktop(child: layar) : layar,
    );
  }
}

/// Pembungkus kios desktop: jalan keluar fullscreen untuk operator
/// stand (ADR-015).
///
/// - **F11**: mengaktifkan/mematikan fullscreen.
/// - **Esc**: keluar dari fullscreen (jendela tetap tanpa title
///   bar; tutup aplikasi lewat Alt+F4 / tombol OS dari taskbar).
///
/// Kegagalan platform ditelan + dicatat: display tidak boleh
/// terganggu hanya karena perintah jendela gagal.
class _KiosDesktop extends StatelessWidget {
  const _KiosDesktop({required this.child});

  final Widget child;

  Future<void> _jalankan(Future<void> Function() aksi) async {
    try {
      await aksi();
    } catch (e) {
      debugPrint('Perintah jendela kios gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.f11) {
          unawaited(
            _jalankan(() async {
              final penuh = await windowManager.isFullScreen();
              await windowManager.setFullScreen(!penuh);
            }),
          );
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          unawaited(_jalankan(() => windowManager.setFullScreen(false)));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
