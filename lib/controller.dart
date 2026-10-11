import 'package:flutter/foundation.dart';

import 'domain.dart';
import 'storage.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppData initial,
    required this.persist,
    this.timeZone = 'Europe/Istanbul',
    this.store,
    this.recovered = false,
  }) : _data = initial;

  AppData _data;
  AppData get data => _data;
  final Future<void> Function(AppData) persist;
  final RecordStore? store;
  final String timeZone;
  final bool recovered;
  bool busy = false;
  String? error;
  bool remindersEnabled = false;
  bool exactReminders = false;
  int pendingReminders = 0;
  DateTime? reminderCoverage;
  String? reminderWarning;
  Future<void> Function(AppData)? reconcile;
  Future<void> Function()? requestReminders;

  /// Mutations compute against latest state; success follows durable commit.
  Future<bool> change(AppData Function(AppData) update) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final next = update(data);
      if (!identical(next, data)) {
        await persist(next);
        _data = next;
      }
      try {
        await reconcile?.call(data);
      } catch (_) {
        reminderWarning = 'reconcile_failed';
      }
      return true;
    } on FormatException {
      error = 'invalid_data';
      return false;
    } on RecordFailure catch (failure) {
      error = failure.code;
      return false;
    } catch (_) {
      error = 'save_failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> exportBackup(String password) async {
    final storage = store;
    if (storage == null || busy) throw const RecordFailure('unavailable');
    return storage.exportBackup(data.toJson(), password);
  }

  Future<AppData> readBackup(String text, String password) async {
    final storage = store;
    if (storage == null || busy) throw const RecordFailure('unavailable');
    return AppData.fromJson(await storage.readBackup(text, password));
  }

  Future<void> activateReminders() async {
    if (busy) return;
    try {
      if (requestReminders == null) throw const RecordFailure('unavailable');
      await requestReminders!();
      await reconcile?.call(data);
    } catch (_) {
      reminderWarning = 'permission_or_platform';
    }
    notifyListeners();
  }

  void remindersChanged() => notifyListeners();
}
