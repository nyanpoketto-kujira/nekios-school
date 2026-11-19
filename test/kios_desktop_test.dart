/// Test tahap Desktop Pameran (ADR-015): kios jendela Windows/Linux.
///
/// Mengunci empat janji:
/// 1. [adalahPlatformDesktop] hanya benar untuk Windows & Linux —
///    platform pameran yang didukung; Android/macOS tidak ikut
///    jalur window_manager.
/// 2. [siapkanJendelaDesktop] benar-benar meminta fullscreen ke
///    platform saat platform menjawab normal.
/// 3. [siapkanJendelaDesktop] selalu selesai normal walau platform
///    melempar kegagalan, jadi startup tidak pernah digagalkan.
/// 4. Jalan keluar operator (F11/Esc) di pembungkus kios desktop
///    benar-benar menggerakkan status fullscreen platform dan
///    tidak mengganggu display.
///
/// Channel window_manager WAJIB di-mock di semua testWidgets di
/// sini: panggilan MethodChannel tanpa handler tidak pernah
/// selesai di zona FakeAsync test (balasan null dari messenger
/// test tidak terkirim), jadi test yang memanggil window_manager
/// tanpa mock akan menggantung selamanya.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/main.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/ui/ui.dart';

/// Sumber remote palsu diam — duplikat kecil dari main_test.dart:
/// server WebSocket asli tidak bisa hidup di zona FakeAsync
/// testWidgets (lihat ADR-013).
class SumberRemoteDiam implements ScheduleSource {
  final StreamController<DisplayEvent> _controller =
      StreamController<DisplayEvent>.broadcast();

  @override
  Stream<DisplayEvent> get events => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() => _controller.close();
}

/// Channel platform window_manager (MethodChannel biasa).
const _kanalJendela = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Status fullscreen "platform" menurut mock + catatan panggilan.
  late bool layarPenuhPlatform;
  late List<String> panggilanJendela;
  late bool gagalSimulasi;

  setUp(() {
    layarPenuhPlatform = false;
    panggilanJendela = [];
    gagalSimulasi = false;
    messenger.setMockMethodCallHandler(_kanalJendela, (call) async {
      if (gagalSimulasi) {
        throw PlatformException(code: 'uji', message: 'gagal simulasi');
      }
      panggilanJendela.add(call.method);
      switch (call.method) {
        case 'isFullScreen':
          return layarPenuhPlatform;
        case 'isMaximized':
        case 'isMinimized':
        case 'isPreventClose':
          // Getter bool lain yang ditanya waitUntilReadyToShow:
          // null di sini membuat cast bool di paket melempar.
          return false;
        case 'setFullScreen':
          final args = call.arguments;
          if (args is Map && args['isFullScreen'] is bool) {
            layarPenuhPlatform = args['isFullScreen'] as bool;
          }
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_kanalJendela, null);
  });

  test('adalahPlatformDesktop hanya Windows & Linux', () {
    expect(adalahPlatformDesktop('windows'), isTrue);
    expect(adalahPlatformDesktop('linux'), isTrue);
    expect(adalahPlatformDesktop('android'), isFalse);
    expect(adalahPlatformDesktop('ios'), isFalse);
    expect(adalahPlatformDesktop('macos'), isFalse);
    expect(adalahPlatformDesktop('fuchsia'), isFalse);
  });

  testWidgets('siapkanJendelaDesktop meminta fullscreen ke platform', (
    tester,
  ) async {
    await siapkanJendelaDesktop();
    // Callback waitUntilReadyToShow dipanggil paket tanpa await —
    // beri satu putaran agar rantai perintahnya sempat berjalan.
    await tester.pump();

    expect(panggilanJendela, contains('ensureInitialized'));
    expect(layarPenuhPlatform, isTrue);
  });

  testWidgets('siapkanJendelaDesktop tetap selesai bila platform gagal', (
    tester,
  ) async {
    gagalSimulasi = true;

    // Tidak boleh melempar dan tidak boleh menggantung: try/catch
    // di siapkanJendelaDesktop menelan kegagalan platform agar
    // startup aplikasi tidak pernah gagal (pola ADR-012).
    await siapkanJendelaDesktop();
  });

  testWidgets('F11 masuk fullscreen dan Esc keluar, display utuh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(NekiosSchoolApp(sumberRemote: SumberRemoteDiam()));
    await tester.pump();
    expect(find.byType(DisplayScreen), findsOneWidget);
    expect(layarPenuhPlatform, isFalse);

    // Host test berjalan di Linux → pembungkus kios desktop aktif.
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    expect(layarPenuhPlatform, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(layarPenuhPlatform, isFalse);

    expect(find.byType(DisplayScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
