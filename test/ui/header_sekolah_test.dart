/// Test HeaderSekolah (ADR-008): logo sekolah opsional ala
/// HeaderClock masjid-you (ADR-032).
///
/// - Tanpa logoBytes: TIDAK ada kotak logo sama sekali (placeholder
///   inisial "S" dihapus — terlihat generik), nama sekolah tampil
///   mulai mentok kiri.
/// - Dengan logoBytes (PNG 1×1 valid): kotak logo key 'header-logo'
///   muncul.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekios_school/domain/domain.dart';
import 'package:nekios_school/ui/ui.dart';

JadwalData _muatDataAsli() => JadwalData.fromJson(
      jsonDecode(File('assets/jadwal-tkj.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// PNG transparan 1×1 yang valid.
final Uint8List _png1x1 = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

Future<void> _pumpHeader(WidgetTester tester, {Uint8List? logoBytes}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeaderSekolah(
          data: _muatDataAsli(),
          sekarang: DateTime(2026, 11, 17, 9, 20, 24),
          logoBytes: logoBytes,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('HeaderSekolah — logo opsional (ADR-008)', () {
    testWidgets('tanpa logo: tidak ada kotak header-logo, nama tampil',
        (tester) async {
      await _pumpHeader(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('header-logo')), findsNothing);
      // Placeholder inisial lama ("S") sudah dihapus total.
      expect(find.text('S'), findsNothing);
      expect(find.text('SMKN 1 UKUI'), findsOneWidget);
    });

    testWidgets('dengan logo: kotak header-logo muncul', (tester) async {
      await _pumpHeader(tester, logoBytes: _png1x1);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('header-logo')), findsOneWidget);
      expect(find.text('SMKN 1 UKUI'), findsOneWidget);
    });
  });
}
