/// Test Fase R1 (ADR-013): CoreWebSocketSource.
///
/// Integrasi sungguhan: server WebSocket sumber ini di port acak
/// (port 0) + klien `NekiosKlien` dari nekios_core — jalur yang
/// sama dengan nekios-remote kelak. Yang dikunci:
/// - pemetaan tiap paket perintah → DisplayEvent + balasan ack,
/// - ping dijawab state.snapshot berisi potret store,
/// - jadwal tidak valid ditolak dengan paket error dan jadwal
///   lama tetap utuh,
/// - logo.set sampai ke DisplayStore (pasang & hapus),
/// - paket rusak tidak memutus koneksi,
/// - port sibuk tidak menjatuhkan sumber/display,
/// - event RemoteConnectionChanged mengikuti sambung/putus klien.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_core/nekios_core.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';

Map<String, dynamic> jsonJadwalAsli() =>
    jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
        as Map<String, dynamic>;

/// Selasa 2026-11-17 09:20:24 — momen skenario desain (slot 09.00).
final selasaPagi = DateTime(2026, 11, 17, 9, 20, 24);

/// Rig test: satu sumber di port acak + daftar event terkumpul +
/// klien-klien yang otomatis ditutup saat teardown.
class RigRemote {
  RigRemote({
    PenyediaSnapshot? penyediaSnapshot,
    Duration intervalCekKoneksi = const Duration(seconds: 1),
  }) : sumber = CoreWebSocketSource(
         port: 0,
         penyediaSnapshot: penyediaSnapshot,
         intervalCekKoneksi: intervalCekKoneksi,
       );

  final CoreWebSocketSource sumber;
  final List<DisplayEvent> events = [];
  final List<NekiosKlien> _klien = [];
  StreamSubscription<DisplayEvent>? _langganan;

  Future<void> mulai() async {
    _langganan = sumber.events.listen(events.add);
    await sumber.start();
  }

  Future<NekiosKlien> sambung() async {
    final klien = NekiosKlien();
    await klien.connect('127.0.0.1', port: sumber.boundPort);
    _klien.add(klien);
    return klien;
  }

  Future<void> tutup() async {
    for (final klien in _klien) {
      await klien.close();
    }
    await _langganan?.cancel();
    await sumber.dispose();
  }
}

/// Tunggu event bertipe [T] berikutnya dari sumber (langganan
/// dibuat SEBELUM perintah dikirim agar tidak terlewat).
Future<T> tungguEvent<T extends DisplayEvent>(RigRemote rig) {
  return rig.sumber.events
      .firstWhere((e) => e is T)
      .timeout(const Duration(seconds: 5))
      .then((e) => e as T);
}

/// Tunggu paket balasan bertipe [type] berikutnya dari display.
Future<NekiosPacket> tungguPaket(NekiosKlien klien, String type) {
  return klien.packets
      .firstWhere((p) => p.type == type)
      .timeout(const Duration(seconds: 5));
}

void main() {
  group('CoreWebSocketSource', () {
    test('start menyalakan server di port acak; start ulang no-op', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();

      expect(rig.sumber.serverAktif, isTrue);
      expect(rig.sumber.gagalBind, isFalse);
      expect(rig.sumber.boundPort, isNonZero);
      final portAwal = rig.sumber.boundPort;
      await rig.sumber.start();
      expect(rig.sumber.boundPort, portAwal);
    });

    test(
      'mading.set → MadingChanged + ack(ofType) + snapshot susulan',
      () async {
        final rig = RigRemote(
          penyediaSnapshot: () => const {'status': 'pelajaran'},
        );
        addTearDown(rig.tutup);
        await rig.mulai();
        final klien = await rig.sambung();

        final eventFuture = tungguEvent<MadingChanged>(rig);
        final ackFuture = tungguPaket(klien, TipePaket.ack);
        final snapshotFuture = tungguPaket(klien, TipePaket.stateSnapshot);
        klien.send(
          const NekiosPacket(
            type: TipePaket.madingSet,
            payload: {'text': 'Halo dari remote'},
          ),
        );

        final event = await eventFuture;
        expect(event.teks, 'Halo dari remote');
        final ack = await ackFuture;
        expect(ack.payload?['ofType'], TipePaket.madingSet);
        // Pola PROTOCOL §5: perintah pengubah keadaan disusuli
        // snapshot terbaru.
        final snapshot = await snapshotFuture;
        expect(snapshot.payload?['status'], 'pelajaran');
      },
    );

    test('mading.set tanpa text → error, tanpa event', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final errorFuture = tungguPaket(klien, TipePaket.error);
      klien.send(
        const NekiosPacket(
          type: TipePaket.madingSet,
          payload: {'bukanText': 1},
        ),
      );
      final error = await errorFuture;
      expect(error.payload?['message'], contains('text'));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(rig.events.whereType<MadingChanged>(), isEmpty);
    });

    test(
      'clock.simulate → ClockSimulated dengan offset ke momen target',
      () async {
        final rig = RigRemote();
        addTearDown(rig.tutup);
        await rig.mulai();
        final klien = await rig.sambung();

        final target = DateTime.now().add(const Duration(hours: 2));
        final eventFuture = tungguEvent<ClockSimulated>(rig);
        final ackFuture = tungguPaket(klien, TipePaket.ack);
        klien.send(
          NekiosPacket(
            type: TipePaket.clockSimulate,
            payload: {'at': target.toIso8601String()},
          ),
        );

        final event = await eventFuture;
        // Offset dihitung dari jam sistem saat paket diproses; beri
        // toleransi longgar untuk waktu tempuh test.
        final selisih = (event.offset - const Duration(hours: 2)).abs();
        expect(selisih, lessThan(const Duration(seconds: 10)));
        expect((await ackFuture).payload?['ofType'], TipePaket.clockSimulate);
      },
    );

    test('clock.simulate dengan "at" rusak → error, tanpa event', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final errorFuture = tungguPaket(klien, TipePaket.error);
      klien.send(
        const NekiosPacket(
          type: TipePaket.clockSimulate,
          payload: {'at': 'bukan-tanggal'},
        ),
      );
      await errorFuture;

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(rig.events.whereType<ClockSimulated>(), isEmpty);
    });

    test('clock.clear → ClockSimulationCleared + ack', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final eventFuture = tungguEvent<ClockSimulationCleared>(rig);
      final ackFuture = tungguPaket(klien, TipePaket.ack);
      klien.send(const NekiosPacket(type: TipePaket.clockClear));

      await eventFuture;
      expect((await ackFuture).payload?['ofType'], TipePaket.clockClear);
    });

    test('logo.set base64 → LogoChanged berisi byte; string kosong '
        '→ LogoChanged(null)', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final byteLogo = [1, 2, 3, 250, 128, 0];
      final pasangFuture = tungguEvent<LogoChanged>(rig);
      klien.send(
        NekiosPacket(
          type: TipePaket.logoSet,
          payload: {'imageBase64': base64Encode(byteLogo)},
        ),
      );
      expect((await pasangFuture).bytes, byteLogo);

      final hapusFuture = tungguEvent<LogoChanged>(rig);
      klien.send(
        const NekiosPacket(
          type: TipePaket.logoSet,
          payload: {'imageBase64': ''},
        ),
      );
      expect((await hapusFuture).bytes, isNull);
    });

    test('logo.set sampai ke DisplayStore: terpasang lalu terhapus', () async {
      final store = DisplayStore();
      addTearDown(store.dispose);
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final langgananStore = rig.sumber.events.listen(store.terima);
      addTearDown(langgananStore.cancel);
      final klien = await rig.sambung();

      final byteLogo = [9, 8, 7, 6];
      final ackPasang = tungguPaket(klien, TipePaket.ack);
      klien.send(
        NekiosPacket(
          type: TipePaket.logoSet,
          payload: {'imageBase64': base64Encode(byteLogo)},
        ),
      );
      await ackPasang;
      await Future<void>.delayed(Duration.zero);
      expect(store.logoBytes, byteLogo);
      expect(store.snapshotPaket()['hasLogo'], isTrue);

      final ackHapus = tungguPaket(klien, TipePaket.ack);
      klien.send(
        const NekiosPacket(
          type: TipePaket.logoSet,
          payload: {'imageBase64': ''},
        ),
      );
      await ackHapus;
      await Future<void>.delayed(Duration.zero);
      expect(store.logoBytes, isNull);
      expect(store.snapshotPaket()['hasLogo'], isFalse);
    });

    test('ping → state.snapshot berisi potret store saat ini', () async {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(ScheduleReplaced(JadwalData.fromJson(jsonJadwalAsli())));
      store.tick(selasaPagi);
      store.terima(const MadingChanged('Halo mading'));
      store.terima(LogoChanged(Uint8List.fromList([1, 2, 3])));

      final rig = RigRemote(penyediaSnapshot: store.snapshotPaket);
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final snapshotFuture = tungguPaket(klien, TipePaket.stateSnapshot);
      klien.send(NekiosPacket.ping());
      final snapshot = await snapshotFuture;
      final payload = snapshot.payload!;
      expect(payload['status'], 'pelajaran');
      expect(payload['jamEfektif'], selasaPagi.toIso8601String());
      expect(payload['simulasiAktif'], isFalse);
      expect(payload['mading'], 'Halo mading');
      expect(payload['hasLogo'], isTrue);
      expect(payload['jamKeAktif'], 3);
      expect(payload['slotAktif']['mulai'], '09.00');
      expect(payload['sisaKeBelDetik'], 24 * 60 + 36);
      final jadwal = payload['jadwal'] as Map<String, dynamic>;
      expect(jadwal['sekolah'], 'SMKN 1 UKUI');
      expect(jadwal['jumlahKelas'], 6);
      expect(jadwal['jumlahHari'], 5);
      expect(jadwal['hariAktif'], 'selasa');
    });

    test('schedule.replace valid → ScheduleReplaced + ack', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final eventFuture = tungguEvent<ScheduleReplaced>(rig);
      final ackFuture = tungguPaket(klien, TipePaket.ack);
      klien.send(
        NekiosPacket(
          type: TipePaket.scheduleReplace,
          payload: jsonJadwalAsli(),
        ),
      );

      final event = await eventFuture;
      expect(event.data.sekolah, 'SMKN 1 UKUI');
      expect(event.data.kelas.length, 6);
      expect((await ackFuture).payload?['ofType'], TipePaket.scheduleReplace);
    });

    test('schedule.replace mapel tak dikenal → error; jadwal lama '
        'di store tetap utuh', () async {
      final store = DisplayStore();
      addTearDown(store.dispose);
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final langgananStore = rig.sumber.events.listen(store.terima);
      addTearDown(langgananStore.cancel);
      final klien = await rig.sambung();

      // Jadwal awal yang sah masuk lebih dulu.
      final ackAwal = tungguPaket(klien, TipePaket.ack);
      klien.send(
        NekiosPacket(
          type: TipePaket.scheduleReplace,
          payload: jsonJadwalAsli(),
        ),
      );
      await ackAwal;
      await Future<void>.delayed(Duration.zero);
      expect(store.data?.sekolah, 'SMKN 1 UKUI');
      final dataAwal = store.data;

      // Jadwal baru: ganti nama sekolah DAN rusak satu foreign key
      // mapel — harus ditolak validasi §7 secara keseluruhan.
      final rusak = jsonJadwalAsli();
      (rusak['meta'] as Map<String, dynamic>)['sekolah'] = 'SEKOLAH PENGGANTI';
      var ketemu = false;
      for (final hari in rusak['hari'] as List<dynamic>) {
        for (final slot
            in (hari as Map<String, dynamic>)['slots'] as List<dynamic>) {
          final entri =
              (slot as Map<String, dynamic>)['entri'] as Map<String, dynamic>?;
          if (entri != null && entri.isNotEmpty) {
            (entri.values.first as Map<String, dynamic>)['mapel'] = 'XXX';
            ketemu = true;
            break;
          }
        }
        if (ketemu) break;
      }
      expect(ketemu, isTrue, reason: 'fixture harus punya entri untuk dirusak');

      final errorFuture = tungguPaket(klien, TipePaket.error);
      klien.send(NekiosPacket(type: TipePaket.scheduleReplace, payload: rusak));
      final error = await errorFuture;
      expect(error.payload?['message'], contains('mapel tidak dikenal'));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      // Jadwal lama tidak bergeming — objek yang sama persis.
      expect(identical(store.data, dataAwal), isTrue);
      expect(store.data?.sekolah, 'SMKN 1 UKUI');
      expect(rig.events.whereType<ScheduleReplaced>(), hasLength(1));
    });

    test('schedule.replace payload rusak strukturnya → error, '
        'tanpa event', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();
      final klien = await rig.sambung();

      final errorFuture = tungguPaket(klien, TipePaket.error);
      klien.send(
        const NekiosPacket(
          type: TipePaket.scheduleReplace,
          payload: {'meta': {}},
        ),
      );
      final error = await errorFuture;
      expect(error.payload?['message'], contains('tidak terbaca'));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(rig.events.whereType<ScheduleReplaced>(), isEmpty);
    });

    test('port sibuk: start() selesai normal, gagalBind, display '
        'tidak jatuh', () async {
      final penahan = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      addTearDown(() => penahan.close(force: true));

      final sumber = CoreWebSocketSource(port: penahan.port);
      addTearDown(sumber.dispose);
      // Tidak boleh melempar.
      await sumber.start();
      expect(sumber.gagalBind, isTrue);
      expect(sumber.galatBind, isNotNull);
      expect(sumber.serverAktif, isFalse);
    });

    test('paket rusak dari klien asing: terhitung, koneksi tetap '
        'hidup, ping tetap dijawab', () async {
      final rig = RigRemote();
      addTearDown(rig.tutup);
      await rig.mulai();

      final ws = await WebSocket.connect(
        'ws://127.0.0.1:${rig.sumber.boundPort}',
      );
      addTearDown(() => ws.close());
      final snapshotFuture = ws
          .map((d) => NekiosPacketCodec.decode(d as String))
          .where(
            (h) => h is PaketValid && h.paket.type == TipePaket.stateSnapshot,
          )
          .first
          .timeout(const Duration(seconds: 5));

      ws.add('ini bukan json sama sekali');
      ws.add('{"v":99,"type":"ping","payload":null}');
      ws.add(NekiosPacketCodec.encode(NekiosPacket.ping()));

      // Koneksi tidak putus: ping yang sah tetap dijawab snapshot.
      await snapshotFuture;

      final batas = DateTime.now().add(const Duration(seconds: 3));
      while (rig.sumber.jumlahPaketTidakValid < 2 &&
          DateTime.now().isBefore(batas)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(rig.sumber.jumlahPaketTidakValid, 2);
    });

    test('RemoteConnectionChanged mengikuti sambung & putus klien', () async {
      final rig = RigRemote(
        intervalCekKoneksi: const Duration(milliseconds: 50),
      );
      addTearDown(rig.tutup);
      await rig.mulai();

      final tersambungFuture = rig.sumber.events
          .firstWhere((e) => e is RemoteConnectionChanged && e.terhubung)
          .timeout(const Duration(seconds: 5));
      final klien = await rig.sambung();
      await tersambungFuture;

      final putusFuture = rig.sumber.events
          .firstWhere((e) => e is RemoteConnectionChanged && !e.terhubung)
          .timeout(const Duration(seconds: 5));
      await klien.close();
      await putusFuture;
    });
  });
}
