import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/sources/sources.dart';
import 'package:nekios_school/state/state.dart';

JadwalData muatDataAsli() => JadwalData.fromJson(
  jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Sumber palsu: menembakkan event yang disuruh test, kapan pun.
class FakeSource implements ScheduleSource {
  final StreamController<DisplayEvent> _controller =
      StreamController<DisplayEvent>.broadcast();

  @override
  Stream<DisplayEvent> get events => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() => _controller.close();

  void tembak(DisplayEvent event) => _controller.add(event);
}

/// Selasa 2026-11-17 09:20:24 — momen skenario desain (slot 09.00).
final selasaPagi = DateTime(2026, 11, 17, 9, 20, 24);

void main() {
  group('DisplayStore', () {
    test('awal: data & keadaan kosong, mading kosong, tanpa simulasi', () {
      final store = DisplayStore();
      expect(store.data, isNull);
      expect(store.keadaan, isNull);
      expect(store.mading, '');
      expect(store.offsetSimulasi, Duration.zero);
      expect(store.simulasiAktif, isFalse);
    });

    test('tick sebelum ada data tidak crash dan keadaan tetap null', () {
      final store = DisplayStore();
      store.tick(selasaPagi);
      expect(store.keadaan, isNull);
    });

    test(
      'ScheduleReplaced lalu tick: keadaan terisi status pelajaran',
      () async {
        final store = DisplayStore();
        final sumber = FakeSource();
        final langganan = sumber.events.listen(store.terima);
        addTearDown(() async {
          await langganan.cancel();
          await sumber.dispose();
          store.dispose();
        });

        sumber.tembak(ScheduleReplaced(muatDataAsli()));
        // Stream bersifat async; beri kesempatan event sampai.
        await Future<void>.delayed(Duration.zero);
        expect(store.data, isNotNull);
        // Keadaan baru terisi setelah tick pertama.
        expect(store.keadaan, isNull);

        store.tick(selasaPagi);
        expect(store.keadaan, isNotNull);
        expect(store.keadaan!.status, StatusSekolah.pelajaran);
        expect(store.keadaan!.slotAktif?.mulai, '09.00');
        expect(store.keadaan!.jamKeAktif, 3);
      },
    );

    test('MadingChanged tersimpan di store', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(const MadingChanged('Selamat datang di pameran'));
      expect(store.mading, 'Selamat datang di pameran');
    });

    test('ClockSimulated menggeser jam sistem malam ke Selasa 09:20', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(ScheduleReplaced(muatDataAsli()));

      // Jam sistem: Senin 2026-11-16 22:00 (malam, di luar jam sekolah).
      final nowSistem = DateTime(2026, 11, 16, 22, 0);
      store.tick(nowSistem);
      expect(store.keadaan!.status, StatusSekolah.pulang);

      // Remote menyimulasikan jam ke Selasa 09:20:24.
      store.terima(ClockSimulated(selasaPagi.difference(nowSistem)));
      expect(store.simulasiAktif, isTrue);
      store.tick(nowSistem);
      expect(store.keadaan!.status, StatusSekolah.pelajaran);
      expect(store.keadaan!.slotAktif?.mulai, '09.00');
      expect(
        store.keadaan!.sisaKeBel,
        const Duration(minutes: 24, seconds: 36),
      );
    });

    test('ClockSimulationCleared mengembalikan ke jam sistem', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(ScheduleReplaced(muatDataAsli()));
      final nowSistem = DateTime(2026, 11, 16, 22, 0);
      store.terima(ClockSimulated(selasaPagi.difference(nowSistem)));
      store.tick(nowSistem);
      expect(store.keadaan!.status, StatusSekolah.pelajaran);

      store.terima(const ClockSimulationCleared());
      expect(store.simulasiAktif, isFalse);
      expect(store.offsetSimulasi, Duration.zero);
      store.tick(nowSistem);
      expect(store.keadaan!.status, StatusSekolah.pulang);
    });

    test('LogoChanged memasang logoBytes; LogoChanged(null) menghapus', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      expect(store.logoBytes, isNull);

      final byteLogo = Uint8List.fromList([1, 2, 3]);
      store.terima(LogoChanged(byteLogo));
      expect(store.logoBytes, byteLogo);

      store.terima(const LogoChanged(null));
      expect(store.logoBytes, isNull);
    });

    test('RemoteConnectionChanged mengubah remoteTerhubung', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      expect(store.remoteTerhubung, isFalse);

      store.terima(const RemoteConnectionChanged(true));
      expect(store.remoteTerhubung, isTrue);

      store.terima(const RemoteConnectionChanged(false));
      expect(store.remoteTerhubung, isFalse);
    });

    test('snapshotPaket sebelum ada data: belumSiap, jadwal null', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      final snapshot = store.snapshotPaket();
      expect(snapshot['status'], 'belumSiap');
      expect(snapshot['jamEfektif'], isNull);
      expect(snapshot['jadwal'], isNull);
      expect(snapshot['hasLogo'], isFalse);
      expect(snapshot['mading'], '');
      expect(snapshot['simulasiAktif'], isFalse);
    });

    test('snapshotPaket saat pelajaran: potret lengkap sesuai kontrak', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      store.terima(ScheduleReplaced(muatDataAsli()));
      store.tick(selasaPagi);
      store.terima(const MadingChanged('Halo mading'));
      store.terima(LogoChanged(Uint8List.fromList([4, 5, 6])));

      final snapshot = store.snapshotPaket();
      expect(snapshot['status'], 'pelajaran');
      expect(snapshot['jamEfektif'], selasaPagi.toIso8601String());
      expect(snapshot['mading'], 'Halo mading');
      expect(snapshot['hasLogo'], isTrue);
      expect(snapshot['jamKeAktif'], 3);
      final slot = snapshot['slotAktif'] as Map<String, dynamic>;
      expect(slot['mulai'], '09.00');
      expect(slot['selesai'], '09.45');
      expect(slot['tipe'], 'pelajaran');
      expect(snapshot['sisaKeBelDetik'], 24 * 60 + 36);
      final jadwal = snapshot['jadwal'] as Map<String, dynamic>;
      expect(jadwal['sekolah'], 'SMKN 1 UKUI');
      expect(jadwal['jumlahKelas'], 6);
      expect(jadwal['jumlahHari'], 5);
      expect(jadwal['hariAktif'], 'selasa');
    });

    test('terima selalu notify; tick identik tidak notify ulang', () {
      final store = DisplayStore();
      addTearDown(store.dispose);
      var notif = 0;
      store.addListener(() => notif++);

      store.terima(ScheduleReplaced(muatDataAsli()));
      expect(notif, 1);

      store.tick(selasaPagi);
      expect(notif, 2);

      // Tick pada momen yang sama persis: snapshot tidak berubah.
      store.tick(selasaPagi);
      expect(notif, 2);

      // Satu detik kemudian countdown berubah: notify lagi.
      store.tick(selasaPagi.add(const Duration(seconds: 1)));
      expect(notif, 3);
    });
  });
}
