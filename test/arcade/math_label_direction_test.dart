import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/draw.dart';

Future<Uint8List> renderLabel(String value, {TextDirection? direction}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  D.text(canvas, value, const Offset(100, 40), size: 32, direction: direction);
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 80);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('KosugiMaru')
      ..addFont(rootBundle.load('assets/fonts/KosugiMaru-Regular.ttf'));
    await loader.load();
  });

  tearDown(() => D.textDirection = TextDirection.ltr);

  test(
    'math gate operations stay LTR without changing the RTL paragraph default',
    () async {
      for (final label in ['×2', '÷2', '+12', '-30']) {
        D.textDirection = TextDirection.ltr;
        final expected = await renderLabel(label);
        D.textDirection = TextDirection.rtl;
        final inheritedRtl = await renderLabel(label);
        final isolatedLtr = await renderLabel(
          label,
          direction: TextDirection.ltr,
        );
        expect(isolatedLtr, orderedEquals(expected), reason: label);
        expect(
          inheritedRtl,
          isNot(orderedEquals(expected)),
          reason: 'Regression must detect the reordered $label',
        );
        expect(D.textDirection, TextDirection.rtl);
        // The override must also participate in the text-layout cache key.
        expect(await renderLabel(label), orderedEquals(inheritedRtl));
      }
    },
  );

  test(
    'both arithmetic gate renderers opt into LTR without changing game labels',
    () {
      for (final file in [
        'lib/arcade/games/g002.dart',
        'lib/arcade/games/g018.dart',
      ]) {
        expect(
          File(file).readAsStringSync(),
          contains('direction: TextDirection.ltr'),
        );
      }
    },
  );
}
