// Original app artwork. Default invocation checks in memory; writing is opt-in.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const teal = ui.Color(0xff006b60);
const cream = ui.Color(0xfff7f6f0);
const amber = ui.Color(0xfff4bd65);

Future<Uint8List> drawIcon(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(size / 100);
  canvas.drawColor(teal, ui.BlendMode.src);
  canvas.save();
  canvas.translate(46, 45);
  canvas.rotate(-math.pi / 4);
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(-27, -13, 54, 26),
      const ui.Radius.circular(13),
    ),
    ui.Paint()..color = cream,
  );
  canvas.drawLine(
    const ui.Offset(0, -10),
    const ui.Offset(0, 10),
    ui.Paint()
      ..color = teal
      ..strokeWidth = 3
      ..strokeCap = ui.StrokeCap.round,
  );
  canvas.restore();
  canvas.drawCircle(const ui.Offset(70, 69), 17, ui.Paint()..color = teal);
  canvas.drawCircle(const ui.Offset(70, 69), 13, ui.Paint()..color = amber);
  canvas.drawPath(
    ui.Path()
      ..moveTo(70, 61)
      ..lineTo(70, 69)
      ..lineTo(76, 72),
    ui.Paint()
      ..color = teal
      ..strokeWidth = 3
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  image.dispose();
  for (var i = 3; i < rgba.length; i += 4) {
    expect(rgba[i], 255, reason: 'Artwork must be fully opaque');
  }
  return rgba;
}

Uint8List rgbPng(int size, Uint8List rgba) {
  final output = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String name, List<int> bytes) {
    final body = Uint8List.fromList([...ascii.encode(name), ...bytes]);
    var crc = 0xffffffff;
    for (final byte in body) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    final length = ByteData(4)..setUint32(0, bytes.length);
    final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
    output
      ..add(length.buffer.asUint8List())
      ..add(body)
      ..add(checksum.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  chunk('IHDR', header.buffer.asUint8List()); // RGB24, no alpha channel.
  final rows = BytesBuilder();
  for (var y = 0; y < size; y++) {
    rows.addByte(0);
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      rows.add(rgba.sublist(i, i + 3));
    }
  }
  chunk('IDAT', ZLibEncoder(level: 9).convert(rows.takeBytes()));
  chunk('IEND', []);
  return output.takeBytes();
}

void main() {
  test('original opaque artwork and native icon dimensions', () async {
    final root = Directory.current;
    final assets = Directory(
      '${root.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final manifest = jsonDecode(
      File('${assets.path}/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final targets = <String, int>{};
    for (final row in manifest['images'] as List<dynamic>) {
      final filename = row['filename'] as String;
      expect(
        RegExp(r'^Icon-App-[0-9.x]+@[123]x\.png$').hasMatch(filename),
        isTrue,
      );
      final sides = (row['size'] as String)
          .split('x')
          .map(double.parse)
          .toList();
      expect(sides[0], sides[1]);
      final pixels =
          sides[0] * double.parse((row['scale'] as String).replaceAll('x', ''));
      expect(pixels, pixels.roundToDouble());
      targets['${assets.path}/$filename'] = pixels.toInt();
    }
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      targets['${root.path}/android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png'] =
          entry.value;
    }
    final encoded = <int, Uint8List>{};
    for (final size in targets.values.toSet()) {
      expect(size, inInclusiveRange(20, 1024));
      final rgba = await drawIcon(size);
      expect(rgba.take(3), [0, 107, 96]);
      final creamPixels = [
        for (var i = 0; i < rgba.length; i += 4)
          if (rgba[i] == 247 && rgba[i + 1] == 246 && rgba[i + 2] == 240) i,
      ];
      expect(
        creamPixels,
        isNotEmpty,
        reason: 'Artwork must include the capsule, not just a background',
      );
      final png = rgbPng(size, rgba);
      expect(png[25], 2, reason: 'PNG must be RGB24');
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, size);
      expect(frame.image.height, size);
      frame.image.dispose();
      codec.dispose();
      encoded[size] = png;
    }
    if (const bool.fromEnvironment('WRITE_ICONS')) {
      for (final entry in targets.entries) {
        final file = File(entry.key);
        expect(
          File(file.resolveSymbolicLinksSync()).uri,
          file.absolute.uri,
          reason: 'Refuse linked icon target',
        );
      }
      for (final entry in targets.entries) {
        File(entry.key).writeAsBytesSync(encoded[entry.value]!, flush: true);
      }
    }
  });
}
