import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'controller.dart';
import 'domain.dart';
import 'photo.dart';
import 'platform.dart';
import 'notifications.dart';
import 'storage.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _openApp();
}

bool _opening = false;
ReminderService? _activeReminders;

Future<void> _openApp() async {
  if (_opening) return;
  _opening = true;
  await _activeReminders?.dispose();
  _activeReminders = null;
  try {
    final directory = await privateRecordDirectory();
    final store = RecordStore.device(
      directory,
      (value) => AppData.fromJson(value),
    );
    final records = await store.load();
    await protectRecordFiles();
    var zone = 'Europe/Istanbul';
    try {
      zone = locationForZone(
        (await FlutterTimezone.getLocalTimezone()).identifier,
      ).name;
    } catch (_) {
      // Each plan form exposes its IANA zone for explicit user confirmation.
    }
    final controller = AppController(
      initial: records == null ? AppData.empty() : AppData.fromJson(records),
      persist: (data) async {
        await protectRecordFiles();
        await store.save(data.toJson());
        try {
          await protectRecordFiles();
        } catch (_) {
          // Encrypted write committed: stop this UI instead of continuing from stale state.
          await _activeReminders?.dispose();
          _activeReminders = null;
          runApp(const LockedRecordsApp());
          rethrow;
        }
      },
      store: store,
      timeZone: zone,
      recovered: store.recovered,
    );
    final reminders = ReminderService(controller);
    _activeReminders = reminders;
    try {
      await reminders.initialize();
    } catch (_) {
      controller.reminderWarning = 'platform_unavailable';
    }
    runApp(
      IlacVaktiApp(
        controller: controller,
        readPhoto: readMedicinePhoto,
        onExport: (password) => shareEncryptedBackup(controller, password),
        onImport: (password) => chooseEncryptedBackup(controller, password),
      ),
    );
  } catch (_) {
    runApp(const LockedRecordsApp());
  } finally {
    _opening = false;
  }
}

class LockedRecordsApp extends StatelessWidget {
  const LockedRecordsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Kayıtlar güvenle açılamadı',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mevcut dosyalar korunuyor. Cihazın kilidini açıp yeniden deneyin. Anahtar kaybolduysa şifreli yedeğiniz gerekir.\n\nRecords could not be opened safely. Existing files are preserved. Unlock the device and retry. A lost key requires your encrypted backup.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openApp,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden dene / Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
