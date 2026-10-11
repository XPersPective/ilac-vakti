import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/controller.dart';
import 'package:ilac_vakti/domain.dart';

void main() {
  test('saved UI state waits for persistence; concurrent mutation cannot overwrite it', () async {
    final flushed = Completer<void>();
    final controller = AppController(
      initial: AppData.empty(),
      persist: (_) => flushed.future,
    );
    addTearDown(controller.dispose);
    final pending = controller.change(
      (data) => data.addPatient(Patient(name: 'Synthetic person')),
    );
    expect(controller.busy, isTrue);
    expect(controller.data.patients, isEmpty);
    expect(
      await controller.change((data) => data.preferences(language: 'en')),
      isFalse,
    );
    flushed.complete();
    expect(await pending, isTrue);
    expect(controller.data.patients.single.name, 'Synthetic person');
    expect(controller.data.language, 'tr');
    expect(controller.busy, isFalse);
  });

  test(
    'failed save preserves state and generic errors never expose health data',
    () async {
      var fail = true;
      final controller = AppController(
        initial: AppData.empty(),
        persist: (_) async {
          if (fail) throw Exception('synthetic-private-name');
        },
      );
      addTearDown(controller.dispose);
      expect(
        await controller.change(
          (data) => data.addPatient(Patient(name: 'Synthetic person')),
        ),
        isFalse,
      );
      expect(controller.data.patients, isEmpty);
      expect(controller.error, 'save_failed');
      fail = false;
      expect(
        await controller.change(
          (data) => data.addPatient(Patient(name: 'Synthetic person')),
        ),
        isTrue,
      );
      expect(controller.error, isNull);
    },
  );

  test(
    'reminder failure never undoes a committed medication confirmation',
    () async {
      final controller = AppController(
        initial: AppData.empty(),
        persist: (_) async {},
      );
      addTearDown(controller.dispose);
      controller.reconcile = (_) async =>
          throw Exception('synthetic platform failure');
      expect(
        await controller.change(
          (data) => data.addPatient(Patient(name: 'Synthetic person')),
        ),
        isTrue,
      );
      expect(controller.data.patients, hasLength(1));
      expect(controller.reminderWarning, 'reconcile_failed');
    },
  );
}
