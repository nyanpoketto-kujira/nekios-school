/// Test paket audio bel di CoreWebSocketSource (ADR-017):
/// `audio.konfigurasi` -> event BelKonfigurasiChanged + ack + snapshot;
/// payload salah -> error; `audio.tes` -> event TesBelDiminta + ack
/// TANPA snapshot susulan. Pola rig sama dengan
/// core_websocket_source_test (server asli port 0 + NekiosKlien).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_core/nekios_core.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';

void main() {
  group('CoreWebSocketSource — audio bel', () {
    late DisplayStore store;
    late CoreWebSocketSource sumber;
    late StreamSubscription<DisplayEvent> langgananStore;
    final events = <DisplayEvent>[];
    final klienList = <NekiosKlien>[];

    setUp(() async {
      events.clear();
      store = DisplayStore();
      sumber = CoreWebSocketSource(
        port: 0,
        penyediaSnapshot: store.snapshotPaket,
      );
      langgananStore = sumber.events.listen((e) {
        events.add(e);
        store.terima(e);
      });
      await sumber.start();
    });

    tearDown(() async {
      for (final k in klienList) {
        await k.close();
      }
      await langgananStore.cancel();
      await sumber.dispose();
      store.dispose();
    });

    Future<NekiosKlien> sambung() async {
      final klien = NekiosKlien();
      await klien.connect('127.0.0.1', port: sumber.boundPort);
      klienList.add(klien);
      return klien;
    }

    Future<NekiosPacket> tungguPaket(NekiosKlien klien, String type) {
      return klien.packets
          .firstWhere((p) => p.type == type)
          .timeout(const Duration(seconds: 5));
    }

    test('audio.konfigurasi valid: event + ack + snapshot belAktif '
        'berubah', () async {
      final klien = await sambung();
      final ackFuture = tungguPaket(klien, TipePaket.ack);
      final snapFuture = tungguPaket(klien, TipePaket.stateSnapshot);
      klien.send(
        const NekiosPacket(
          type: TipePaket.audioKonfigurasi,
          payload: {'belAktif': false},
        ),
      );
      final ack = await ackFuture;
      expect(ack.payload?['ofType'], TipePaket.audioKonfigurasi);
      final snap = await snapFuture;
      expect(snap.payload?['belAktif'], isFalse);
      expect(store.belAktif, isFalse);
      expect(events.whereType<BelKonfigurasiChanged>(), hasLength(1));
    });

    test('audio.konfigurasi payload salah: error, keadaan utuh', () async {
      final klien = await sambung();
      final errFuture = tungguPaket(klien, TipePaket.error);
      klien.send(
        const NekiosPacket(
          type: TipePaket.audioKonfigurasi,
          payload: {'belAktif': 'ya'},
        ),
      );
      final err = await errFuture;
      expect(err.payload?['message'], contains('belAktif'));
      expect(store.belAktif, isTrue);
      expect(events.whereType<BelKonfigurasiChanged>(), isEmpty);
    });

    test('audio.tes: event + ack saja tanpa snapshot', () async {
      final klien = await sambung();
      final diterima = <NekiosPacket>[];
      final sub = klien.packets.listen(diterima.add);
      addTearDown(sub.cancel);
      final ackFuture = tungguPaket(klien, TipePaket.ack);
      klien.send(const NekiosPacket(type: TipePaket.audioTes));
      final ack = await ackFuture;
      expect(ack.payload?['ofType'], TipePaket.audioTes);
      expect(events.whereType<TesBelDiminta>(), hasLength(1));
      // Beri waktu paket susulan (bila ada) untuk tiba, lalu pastikan
      // hanya ack yang datang.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(diterima.map((p) => p.type), [TipePaket.ack]);
    });
  });
}
