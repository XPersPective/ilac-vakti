import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const maxRecordBytes = 1024 * 1024;
const maxEnvelopeBytes = 2 * maxRecordBytes;

List<int> _random(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}

class RecordFailure implements Exception {
  const RecordFailure(this.code);
  final String code;
  @override
  String toString() => 'RecordFailure: $code';
}

Future<List<int>> _passwordKey(String password, List<int> salt) async {
  if (password.length < 12 || password.length > 256) {
    throw const RecordFailure('password_length');
  }
  return (await Argon2id(
    memory: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  ).deriveKeyFromPassword(password: password, nonce: salt)).extractBytes();
}

Future<String> _seal(
  Map<String, dynamic> data,
  List<int> key,
  String kind,
  int revision,
  List<int>? salt,
) async {
  final plain = utf8.encode(jsonEncode(data));
  if (plain.length > maxRecordBytes) throw const RecordFailure('record_limit');
  final aad = utf8.encode('ilac-vakti:1:$kind:$revision');
  final box = await AesGcm.with256bits().encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: _random(12),
    aad: aad,
  );
  return jsonEncode({
    'format': 1,
    'kind': kind,
    'revision': revision,
    if (salt != null) 'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'mac': base64Encode(box.mac.bytes),
    'cipher': base64Encode(box.cipherText),
  });
}

Map<String, dynamic> _envelope(String text, String kind) {
  if (utf8.encode(text).length > maxEnvelopeBytes) {
    throw const RecordFailure('record_limit');
  }
  try {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic> ||
        data['format'] != 1 ||
        data['kind'] != kind ||
        data['revision'] is! int ||
        data['revision'] < 0 ||
        data['revision'] > 9007199254740991) {
      throw const RecordFailure('invalid_format');
    }
    for (final entry in {
      'nonce': 12,
      'mac': 16,
      if (kind == 'backup') 'salt': 16,
    }.entries) {
      if (data[entry.key] is! String ||
          base64Decode(data[entry.key]).length != entry.value) {
        throw const RecordFailure('invalid_format');
      }
    }
    if (data['cipher'] is! String ||
        base64Decode(data['cipher']).length > maxRecordBytes) {
      throw const RecordFailure('record_limit');
    }
    return data;
  } on RecordFailure {
    rethrow;
  } catch (_) {
    throw const RecordFailure('invalid_format');
  }
}

Future<Map<String, dynamic>> _open(
  Map<String, dynamic> data,
  List<int> key,
) async {
  try {
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode(data['cipher']),
        nonce: base64Decode(data['nonce']),
        mac: Mac(base64Decode(data['mac'])),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode('ilac-vakti:1:${data['kind']}:${data['revision']}'),
    );
    final decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map<String, dynamic>) {
      throw const RecordFailure('invalid_records');
    }
    return decoded;
  } catch (_) {
    throw const RecordFailure('authentication_failed');
  }
}

// Top-level boundaries capture only sendable values, never RecordStore's Future queue.
Future<String> _sealOffThread(
  Map<String, dynamic> data,
  List<int> key,
  int revision,
) => Isolate.run(() => _seal(data, key, 'device', revision, null));

Future<Map<String, dynamic>> _openOffThread(
  Map<String, dynamic> data,
  List<int> key,
) => Isolate.run(() => _open(data, key));

Future<String> _exportOffThread(Map<String, dynamic> data, String password) =>
    Isolate.run(() async {
      final salt = _random(16);
      final key = await _passwordKey(password, salt);
      return _seal(data, key, 'backup', 0, salt);
    });

Future<Map<String, dynamic>> _importOffThread(
  Map<String, dynamic> data,
  String password,
) => Isolate.run(() async {
  final key = await _passwordKey(password, base64Decode(data['salt']));
  return _open(data, key);
});

/// One app-process writer. Never store plaintext backups or silently reset data.
class RecordStore {
  RecordStore({
    required this.directory,
    required this.readKey,
    required this.writeKey,
    required this.validate,
  });

  factory RecordStore.device(
    Directory directory,
    void Function(Map<String, dynamic>) validate,
  ) {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    return RecordStore(
      directory: directory,
      validate: validate,
      readKey: () => storage.read(key: 'ilac_vakti_records_v1'),
      writeKey: (value) =>
          storage.write(key: 'ilac_vakti_records_v1', value: value),
    );
  }

  final Directory directory;
  final Future<String?> Function() readKey;
  final Future<void> Function(String) writeKey;
  final void Function(Map<String, dynamic>) validate;
  Future<void> _queue = Future.value();
  List<int>? _key;
  int _revision = 0;
  bool _loaded = false;
  bool recovered = false;

  File _slot(int index) => File('${directory.path}/records-$index.ivault');

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>?> load() => _serial(() async {
    if (_loaded) throw const RecordFailure('already_loaded');
    if (await FileSystemEntity.isLink(directory.path)) {
      throw const RecordFailure('linked_storage');
    }
    await directory.create(recursive: true);
    final existing = <File>[];
    for (var index = 0; index < 2; index++) {
      final file = _slot(index);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const RecordFailure('invalid_storage');
      }
      if (type == FileSystemEntityType.file) existing.add(file);
    }
    final stored = await readKey();
    if (stored == null && existing.isNotEmpty) {
      throw const RecordFailure('missing_device_key');
    }
    try {
      _key = stored == null ? _random(32) : base64Decode(stored);
      if (_key!.length != 32) throw const RecordFailure('invalid_device_key');
    } catch (_) {
      throw const RecordFailure('invalid_device_key');
    }
    if (stored == null) await writeKey(base64Encode(_key!));
    final valid = <({int revision, Map<String, dynamic> data})>[];
    for (final file in existing) {
      try {
        if (await file.length() > maxEnvelopeBytes) {
          throw const RecordFailure('record_limit');
        }
        final envelope = _envelope(await file.readAsString(), 'device');
        final key = List<int>.from(_key!);
        final data = await _openOffThread(envelope, key);
        validate(data);
        valid.add((revision: envelope['revision'] as int, data: data));
      } catch (_) {
        recovered = true;
      }
    }
    if (valid.isEmpty && existing.isNotEmpty) {
      throw const RecordFailure('unreadable_records');
    }
    valid.sort((a, b) => b.revision.compareTo(a.revision));
    _revision = valid.isEmpty ? 0 : valid.first.revision;
    _loaded = true;
    return valid.isEmpty ? null : valid.first.data;
  });

  Future<void> save(Map<String, dynamic> input) async {
    // ponytail: O(n) encrypted snapshots, bounded at1MiB; use encrypted SQLite if histories outgrow this limit.
    final data = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
    validate(data);
    await _serial(() async {
      if (!_loaded) throw const RecordFailure('not_loaded');
      final revision = _revision + 1;
      final key = List<int>.from(_key!);
      final text = await _sealOffThread(data, key, revision);
      final file = _slot(revision % 2);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const RecordFailure('invalid_storage');
      }
      // The other authenticated slot survives interruption during this write.
      await file.writeAsString(text, flush: true);
      _revision = revision;
    });
  }

  Future<String> exportBackup(
    Map<String, dynamic> input,
    String password,
  ) async {
    final data = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
    validate(data);
    return _exportOffThread(data, password);
  }

  /// Returns a validated draft; the user must approve replacement before save.
  Future<Map<String, dynamic>> readBackup(String text, String password) async {
    final envelope = _envelope(text, 'backup');
    final result = await _importOffThread(envelope, password);
    validate(result);
    return result;
  }
}
