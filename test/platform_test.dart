import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/platform.dart';
import 'package:ilac_vakti/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native fixed-directory protection fails closed and never receives a caller path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ilac-vakti-protected-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('ilac_vakti/private_records');
    var protected = false;
    var path = directory.path;
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.arguments, isNull);
          methods.add(call.method);
          if (call.method == 'getDirectory') return path;
          if (call.method == 'protectFiles') return protected;
          throw const FormatException('Unexpected native method');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect((await privateRecordDirectory()).path, directory.path);
    await expectLater(protectRecordFiles(), throwsA(isA<RecordFailure>()));
    protected = true;
    await protectRecordFiles();
    path = 'relative/path';
    await expectLater(privateRecordDirectory(), throwsA(isA<RecordFailure>()));
    expect(methods, [
      'getDirectory',
      'protectFiles',
      'protectFiles',
      'getDirectory',
    ]);
  });
}
