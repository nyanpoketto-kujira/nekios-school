import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/sources/sources.dart';

void main() {
  group('AssetScheduleSource', () {
    test('loader palsu: start meng-emit satu ScheduleReplaced valid',
        () async {
      final teksAsli = File('assets/jadwal-tkj.json').readAsStringSync();
      final sumber = AssetScheduleSource(pemuat: () async => teksAsli);
      addTearDown(sumber.dispose);

      final eventPertama = sumber.events.first;
      await sumber.start();
      final event = await eventPertama;

      expect(event, isA<ScheduleReplaced>());
      final data = (event as ScheduleReplaced).data;
      expect(data.sekolah, 'SMKN 1 UKUI');
      expect(data.kelas.length, 6);
      expect(data.hari.length, 5);
      expect(data.hariByNama('selasa')?.slots.length, 12);
    });

    test('start dua kali tidak meng-emit ulang', () async {
      final teksAsli = File('assets/jadwal-tkj.json').readAsStringSync();
      final sumber = AssetScheduleSource(pemuat: () async => teksAsli);
      addTearDown(sumber.dispose);

      final terkumpul = <DisplayEvent>[];
      final langganan = sumber.events.listen(terkumpul.add);
      addTearDown(langganan.cancel);

      await sumber.start();
      await sumber.start();
      await Future<void>.delayed(Duration.zero);
      expect(terkumpul.length, 1);
    });

    test('JSON rusak: start melempar error', () async {
      final sumber = AssetScheduleSource(pemuat: () async => '{bukan json');
      addTearDown(sumber.dispose);
      await expectLater(sumber.start(), throwsA(anything));
    });
  });
}
