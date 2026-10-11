import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  const ocr = MethodChannel('google_mlkit_text_recognizer');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory fixture;
  late Directory owned;
  late File image;
  String? selectedPath;
  String recognizedText = '';
  bool failOcr = false;
  bool failClose = false;
  late List<String> calls;

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('ilac-vakti-photo-test-');
    owned = await Directory('${fixture.path}/owned-cache').create();
    image = await File('${owned.path}/synthetic.jpg').writeAsBytes([1]);
    selectedPath = image.path;
    recognizedText = 'Synthetic draft';
    failOcr = false;
    failClose = false;
    calls = [];
    messenger.setMockMethodCallHandler(picker, (call) async {
      // Windows host exercises the non-Android branch; no lost-data call is valid.
      expect(call.method, 'pickImage');
      expect(call.arguments['requestFullMetadata'], isFalse);
      expect(call.arguments['maxWidth'], 2048);
      expect(call.arguments['maxHeight'], 2048);
      calls.add('pick');
      return selectedPath;
    });
    messenger.setMockMethodCallHandler(paths, (call) async {
      expect(call.method, 'getTemporaryDirectory');
      return owned.path;
    });
    messenger.setMockMethodCallHandler(ocr, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'vision#startTextRecognizer':
          if (failOcr) {
            throw PlatformException(code: 'synthetic_ocr_failure');
          }
          return {'text': recognizedText, 'blocks': []};
        case 'vision#closeTextRecognizer':
          if (failClose) {
            throw PlatformException(code: 'synthetic_close_failure');
          }
          return null;
        default:
          fail('Unexpected OCR method');
      }
    });
  });
  tearDown(() async {
    for (final channel in [picker, ocr, paths]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await fixture.delete(recursive: true);
  });

  test('cancellation never invokes OCR or deletes a photo', () async {
    selectedPath = null;
    expect(await readMedicinePhoto(), isNull);
    expect(calls, ['pick']);
    expect(await image.exists(), isTrue);
  });

  for (final length in [0, 20 * 1024 * 1024 + 1]) {
    test(
      'image size $length rejects before OCR and cleans owned cache',
      () async {
        final file = await image.open(mode: FileMode.write);
        await file.truncate(length);
        await file.close();
        await expectLater(readMedicinePhoto(), throwsFormatException);
        expect(calls, ['pick', 'vision#closeTextRecognizer']);
        expect(await image.exists(), isFalse);
      },
    );
  }

  test('OCR failure closes recognizer and cleans owned cache', () async {
    failOcr = true;
    await expectLater(readMedicinePhoto(), throwsA(isA<PlatformException>()));
    expect(calls, [
      'pick',
      'vision#startTextRecognizer',
      'vision#closeTextRecognizer',
    ]);
    expect(await image.exists(), isFalse);
  });

  test('OCR returns sanitized untrusted text and cleans owned cache', () async {
    recognizedText = '  Synthetic\u0000 draft\nLine\t2\u007f  ';
    expect(await readMedicinePhoto(), 'Synthetic draft\nLine\t2');
    expect(calls.last, 'vision#closeTextRecognizer');
    expect(await image.exists(), isFalse);
  });

  for (final text in ['', 'x' * 12001]) {
    test(
      'unusable text length ${text.length} closes and cleans cache',
      () async {
        recognizedText = text;
        await expectLater(readMedicinePhoto(), throwsFormatException);
        expect(calls.last, 'vision#closeTextRecognizer');
        expect(await image.exists(), isFalse);
      },
    );
  }

  test('original outside owned cache survives OCR', () async {
    final original = await File('${fixture.path}/original.jpg')
        .writeAsBytes([7, 8]);
    selectedPath = original.path;
    expect(await readMedicinePhoto(), 'Synthetic draft');
    expect(await original.readAsBytes(), [7, 8]);
  });

  test('recognizer close failure still cleans owned cache', () async {
    failClose = true;
    await expectLater(readMedicinePhoto(), throwsA(isA<PlatformException>()));
    expect(calls.last, 'vision#closeTextRecognizer');
    expect(await image.exists(), isFalse);
  });
}
