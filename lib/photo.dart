import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<void> _discardOwnedPhoto(String path) async {
  try {
    final root = await (await getTemporaryDirectory()).resolveSymbolicLinks();
    final file = File(path);
    final resolved = await file.resolveSymbolicLinks();
    if (resolved.startsWith('$root${Platform.pathSeparator}') &&
        !await FileSystemEntity.isLink(path)) {
      await file.delete();
    }
  } catch (_) {
    // Native cache also expires; never delete a user's original photo.
  }
}

/// Local Latin OCR produces untrusted text only; the UI confirms every plan.
Future<String?> readMedicinePhoto() async {
  final picker = ImagePicker();
  final recovered = Platform.isAndroid
      ? await picker.retrieveLostData()
      : LostDataResponse.empty();
  if (recovered.exception != null) {
    throw const FormatException('Photo unavailable');
  }
  final files = recovered.files;
  final photo = files != null && files.isNotEmpty
      ? files.first
      : await picker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
  if (photo == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final length = await File(photo.path).length();
    if (length == 0 || length > 20 * 1024 * 1024) {
      throw const FormatException('Photo limit');
    }
    final result = await recognizer.processImage(
      InputImage.fromFilePath(photo.path),
    );
    final text = result.text
        .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
        .trim();
    if (text.isEmpty || text.length > 12000) {
      throw const FormatException('No usable text');
    }
    return text;
  } finally {
    try {
      await recognizer.close();
    } finally {
      await _discardOwnedPhoto(photo.path);
      if (files != null) {
        for (final extra in files.skip(1)) {
          await _discardOwnedPhoto(extra.path);
        }
      }
    }
  }
}
