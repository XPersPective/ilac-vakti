import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'controller.dart';
import 'domain.dart';
import 'storage.dart';

const _records = MethodChannel('ilac_vakti/private_records');

Future<Directory> privateRecordDirectory() async {
  final path = await _records.invokeMethod<String>('getDirectory');
  if (path == null || path.isEmpty || !Directory(path).isAbsolute) {
    throw const RecordFailure('protected_directory');
  }
  final directory = Directory(path);
  if (await FileSystemEntity.isLink(path) || !await directory.exists()) {
    throw const RecordFailure('protected_directory');
  }
  return directory;
}

Future<void> protectRecordFiles() async {
  if (await _records.invokeMethod<bool>('protectFiles') != true) {
    throw const RecordFailure('backup_protection');
  }
}

Future<void> shareEncryptedBackup(
  AppController controller,
  String password,
) async {
  final backup = await controller.exportBackup(password);
  final temporary = await getTemporaryDirectory();
  final directory = Directory('${temporary.path}/encrypted-exports');
  if (await FileSystemEntity.isLink(directory.path)) {
    throw const RecordFailure('linked_export');
  }
  await directory.create();
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is File &&
        RegExp(r'^backup-[a-f0-9]{32}\.ilacbackup$')
            .hasMatch(entity.uri.pathSegments.last) &&
        !await FileSystemEntity.isLink(entity.path)) {
      await entity.delete();
    }
  }
  final file = File('${directory.path}/backup-${newId()}.ilacbackup');
  await file.writeAsString(backup, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/octet-stream')],
      fileNameOverrides: ['ilac-vakti.ilacbackup'],
      // Valid nonempty anchor required on iPad; no patient data in chooser text.
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    ),
  );
}

Future<AppData?> chooseEncryptedBackup(
  AppController controller,
  String password,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Encrypted backup',
        extensions: ['ilacbackup'],
        uniformTypeIdentifiers: ['public.data'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > maxEnvelopeBytes) {
    throw const RecordFailure('record_limit');
  }
  final bytes = <int>[];
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > maxEnvelopeBytes) {
      throw const RecordFailure('record_limit');
    }
    bytes.addAll(chunk);
  }
  return controller.readBackup(utf8.decode(bytes), password);
}
