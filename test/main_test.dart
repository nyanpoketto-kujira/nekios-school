/// Test Fase 5 (ADR-012): mode kios saat startup.
///
/// Mengunci dua janji [aktifkanModeKios]:
/// 1. Kedua pemanggilan platform benar-benar dilakukan —
///    SystemChrome immersiveSticky + WakelockPlus.enable().
/// 2. Kegagalan platform TIDAK menggagalkan pemanggilan: fungsi
///    selalu selesai normal, jadi `runApp` di `main()` tetap
///    tercapai walau wakelock gagal (persis semangat pola
///    nekios-mosque tv_display).
///
/// Channel wakelock_plus adalah Pigeon BasicMessageChannel
/// (bukan MethodChannel biasa); mock-nya menjawab dengan amplop
/// sukses StandardMessageCodec berisi `[null]`, format balasan
/// yang diharapkan kode hasil-generate Pigeon untuk API `void`.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/main.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/ui/ui.dart';

/// Sumber remote palsu untuk widget test: server WebSocket asli
/// (dart:io HttpServer) tidak bisa hidup di zona FakeAsync
/// testWidgets — timer internal HttpServer akan dianggap bocor
/// oleh invariant test. Perilaku server sungguhan diuji terpisah
/// di test/sources/core_websocket_source_test.dart (Fase R1).
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

/// Nama channel Pigeon untuk `WakelockPlusApi.toggle` pada
/// wakelock_plus_platform_interface (tanpa suffix pesan).
const _kanalToggleWakelock =
    'dev.flutter.pigeon.wakelock_plus_platform_interface.'
    'WakelockPlusApi.toggle';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> panggilanPlatform;
  late int jumlahToggleWakelock;

  setUp(() {
    panggilanPlatform = [];
    jumlahToggleWakelock = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      panggilanPlatform.add(call);
      return null;
    });
    messenger.setMockMessageHandler(_kanalToggleWakelock, (pesan) async {
      jumlahToggleWakelock++;
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMessageHandler(_kanalToggleWakelock, null);
  });

  testWidgets('aktifkanModeKios memanggil immersiveSticky + wakelock', (
    tester,
  ) async {
    await aktifkanModeKios();

    final modeUi = panggilanPlatform
        .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
        .toList();
    expect(modeUi, hasLength(1));
    expect(modeUi.single.arguments, 'SystemUiMode.immersiveSticky');
    expect(jumlahToggleWakelock, 1);
  });

  testWidgets('aktifkanModeKios tetap selesai bila wakelock gagal', (
    tester,
  ) async {
    // Balasan error ala Pigeon: amplop [kode, pesan, detail] membuat
    // kode hasil-generate melempar PlatformException di sisi Dart —
    // persis kegagalan platform sungguhan, tanpa error liar di zone
    // test (melempar langsung dari handler mock akan diteruskan
    // messenger sebagai error tak tertangani).
    messenger.setMockMessageHandler(_kanalToggleWakelock, (pesan) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[
        'uji',
        'gagal simulasi',
        null,
      ]);
    });

    // Tidak boleh melempar: try/catch di aktifkanModeKios menelan
    // kegagalan platform agar startup aplikasi tidak pernah gagal.
    await aktifkanModeKios();
  });

  testWidgets('NekiosSchoolApp tetap pump normal dengan binding standar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(NekiosSchoolApp(sumberRemote: SumberRemoteDiam()));
    await tester.pump();

    expect(find.byType(DisplayScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
