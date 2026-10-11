import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/domain.dart';
import 'package:ilac_vakti/storage.dart';

void main() {
  test(
    'real domain survives encrypted restart and rejects foreign patient backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ilac-vakti-domain-storage-',
      );
      addTearDown(() => directory.delete(recursive: true));
      String? key;
      RecordStore store({bool strict = true}) => RecordStore(
        directory: directory,
        readKey: () async => key,
        writeKey: (value) async => key = value,
        validate: (value) {
          if (strict) AppData.fromJson(value);
        },
      );
      final patient = Patient(name: 'Synthetic patient');
      final start = DateTime.utc(2026, 10, 11, 8);
      final plan = MedicinePlan(
        patientId: patient.id,
        name: 'Synthetic medicine',
        dose: 'User-entered dose',
        confirmed: true,
        startUtc: start,
        endUtc: start.add(const Duration(days: 2)),
        timeZone: 'Europe/Istanbul',
        intervalMinutes: 480,
      );
      var data = AppData.empty().addPatient(patient).addPlan(plan);
      final occurrence = data
          .occurrences(start, start.add(const Duration(days: 1)))
          .first;
      data = data.record(
        occurrence,
        ConfirmationStatus.taken,
        start.add(const Duration(minutes: 1)),
      );
      final first = store();
      await first.load();
      await first.save(data.toJson());
      final loaded = AppData.fromJson(await store().load());
      expect(loaded.toJson(), data.toJson());
      expect(loaded.statusFor(occurrence.id), ConfirmationStatus.taken);
      final invalid = data.toJson();
      (invalid['plans'] as List).first['patientId'] = 'f' * 32;
      final backup = await store(strict: false)
          .exportBackup(invalid, 'synthetic-backup-password');
      await expectLater(
        first.readBackup(backup, 'synthetic-backup-password'),
        throwsA(isA<FormatException>()),
      );
      expect(AppData.fromJson(await store().load()).toJson(), data.toJson());
    },
  );
}
