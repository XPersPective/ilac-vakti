import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  String? key;
  RecordStore store() => RecordStore(
    directory: directory,
    readKey: () async => key,
    writeKey: (value) async => key = value,
    validate: (data) {
      if (data['schema'] != 1 || data['value'] is! String) {
        throw const FormatException('Invalid synthetic records');
      }
    },
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'ilac-vakti-storage-test-',
    );
    key = null;
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'native Android key operations never request reset on failure',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      expect(await RecordStore.device(directory, (_) {}).load(), isNull);
      expect(calls.map((call) => call.method), ['read', 'write']);
      for (final call in calls) {
        expect(call.arguments['key'], 'ilac_vakti_records_v1');
        expect(call.arguments['options']['resetOnError'], 'false');
      }
    },
  );

  test('durable encrypted snapshots recover prior committed slot after interrupted write', () async {
    final first = store();
    expect(await first.load(), isNull);
    await first.save({'schema': 1, 'value': 'synthetic-first'});
    await first.save({'schema': 1, 'value': 'synthetic-second'});
    expect(await store().load(), {'schema': 1, 'value': 'synthetic-second'});
    for (final file in directory.listSync().whereType<File>()) {
      expect(await file.readAsString(), isNot(contains('synthetic')));
    }
    await File('${directory.path}/records-0.ivault')
        .writeAsString('{interrupted', flush: true);
    final recovered = store();
    expect(await recovered.load(), {'schema': 1, 'value': 'synthetic-first'});
    expect(recovered.recovered, isTrue);
    await recovered.save({'schema': 1, 'value': 'synthetic-repaired'});
    expect(await store().load(), {'schema': 1, 'value': 'synthetic-repaired'});
  });

  test('missing key, invalid records and total corruption never overwrite existing files', () async {
    final first = store();
    await first.load();
    await first.save({'schema': 1, 'value': 'synthetic-record'});
    final file = File('${directory.path}/records-1.ivault');
    final before = await file.readAsBytes();
    await expectLater(
      first.save({'schema': 999}),
      throwsA(isA<FormatException>()),
    );
    expect(await file.readAsBytes(), before);
    key = null;
    await expectLater(store().load(), throwsA(isA<RecordFailure>()));
    expect(key, isNull);
    expect(await file.readAsBytes(), before);
    key = base64Encode(List.filled(32, 3));
    await expectLater(store().load(), throwsA(isA<RecordFailure>()));
    expect(await file.readAsBytes(), before);
  });

  test('authenticated password backup rejects tampering, wrong password and schema without saves', () async {
    final first = store();
    await first.load();
    await first.save({'schema': 1, 'value': 'synthetic-record'});
    final backup = await first.exportBackup({
      'schema': 1,
      'value': 'synthetic-backup',
    }, 'twelve-or-more-characters');
    expect(backup, isNot(contains('synthetic')));
    expect(await first.readBackup(backup, 'twelve-or-more-characters'), {
      'schema': 1,
      'value': 'synthetic-backup',
    });
    await expectLater(
      first.readBackup(backup, 'wrong-password-long'),
      throwsA(isA<RecordFailure>()),
    );
    final modified = jsonDecode(backup) as Map<String, dynamic>;
    modified['revision'] = 1;
    await expectLater(
      first.readBackup(jsonEncode(modified), 'twelve-or-more-characters'),
      throwsA(isA<RecordFailure>()),
    );
    modified['format'] = 2;
    await expectLater(
      first.readBackup(jsonEncode(modified), 'twelve-or-more-characters'),
      throwsA(isA<RecordFailure>()),
    );
    await expectLater(
      first.readBackup(
        'x' * (maxEnvelopeBytes + 1),
        'twelve-or-more-characters',
      ),
      throwsA(isA<RecordFailure>()),
    );
    final file = File('${directory.path}/records-1.ivault');
    final before = await file.readAsBytes();
    final permissive = RecordStore(
      directory: directory,
      readKey: () async => key,
      writeKey: (value) async => key = value,
      validate: (_) {},
    );
    final invalidSchema = await permissive.exportBackup({
      'schema': 999,
      'value': 'authenticated-but-invalid',
    }, 'twelve-or-more-characters');
    await expectLater(
      first.readBackup(invalidSchema, 'twelve-or-more-characters'),
      throwsA(isA<FormatException>()),
    );
    expect(await file.readAsBytes(), before);
    expect(await store().load(), {'schema': 1, 'value': 'synthetic-record'});
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('save captures nested input at invocation before queue runs', () async {
    final first = store();
    await first.load();
    final input = <String, dynamic>{
      'schema': 1,
      'value': 'before',
      'nested': {'value': 'original'},
    };
    final pending = first.save(input);
    input['value'] = 'after';
    (input['nested'] as Map)['value'] = 'mutated';
    await pending;
    expect(await store().load(), {
      'schema': 1,
      'value': 'before',
      'nested': {'value': 'original'},
    });
  });

  test(
    'serialized commits survive failed save and keep last successful record',
    () async {
      final first = store();
      await first.load();
      final invalid = first.save({'schema': 0});
      final valid = first.save({'schema': 1, 'value': 'last'});
      await expectLater(invalid, throwsA(isA<FormatException>()));
      await valid;
      expect(await store().load(), {'schema': 1, 'value': 'last'});
    },
  );
}
