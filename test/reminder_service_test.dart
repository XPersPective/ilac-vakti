import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ilac_vakti/controller.dart';
import 'package:ilac_vakti/domain.dart';
import 'package:ilac_vakti/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late AppController controller;
  late ReminderService service;
  final requests = <Map<String, dynamic>>[];
  final calls = <String>[];
  bool permitted = false;
  bool failSchedule = false;
  Completer<void>? blocked;
  Completer<void>? pendingBlocked;
  bool failPending = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    requests.clear();
    calls.clear();
    permitted = false;
    failSchedule = false;
    blocked = null;
    pendingBlocked = null;
    failPending = false;
    final patient = Patient(name: 'Synthetic private person');
    final start = DateTime.now().toUtc().add(const Duration(minutes: 5));
    controller = AppController(
      initial: AppData(
        patients: [patient],
        plans: [
          MedicinePlan(
            patientId: patient.id,
            name: 'Synthetic private medicine',
            dose: 'Entered dose',
            confirmed: true,
            startUtc: start,
            endUtc: start.add(const Duration(days: 1)),
            timeZone: 'Europe/Istanbul',
            intervalMinutes: 60,
          ),
        ],
      ),
      persist: (_) async {},
    );
    service = ReminderService(controller);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'canScheduleExactNotifications':
              return false;
            case 'areNotificationsEnabled':
              return permitted;
            case 'requestNotificationsPermission':
              permitted = true;
              return true;
            case 'requestExactAlarmsPermission':
              return false;
            case 'cancelAllPendingNotifications':
              requests.clear();
              return null;
            case 'zonedSchedule':
              if (blocked != null) await blocked!.future;
              if (failSchedule) {
                throw PlatformException(code: 'synthetic_schedule_failure');
              }
              final args = Map<String, dynamic>.from(call.arguments as Map);
              requests.add({
                'id': args['id'],
                'title': args['title'],
                'body': args['body'],
                'payload': args['payload'],
              });
              expect(args.toString(), isNot(contains('Synthetic private')));
              return null;
            case 'pendingNotificationRequests':
              if (pendingBlocked != null) await pendingBlocked!.future;
              if (failPending) {
                failPending = false;
                pendingBlocked = null;
                throw PlatformException(code: 'synthetic_pending_failure');
              }
              return requests;
            default:
              throw PlatformException(code: 'unexpected_${call.method}');
          }
        });
  });
  tearDown(() async {
    await service.dispose();
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('denied permission clears stale queue without prompting; user request enables approximate schedule', () async {
    await service.initialize();
    expect(controller.pendingReminders, 0);
    expect(controller.reminderWarning, 'permission_denied');
    expect(calls, isNot(contains('requestNotificationsPermission')));
    await controller.activateReminders();
    expect(controller.remindersEnabled, isTrue);
    expect(controller.exactReminders, isFalse);
    expect(requests, isNotEmpty);
    expect(controller.pendingReminders, requests.length);
    expect(controller.reminderCoverage, isNotNull);
    final plan = controller.data.plans.single;
    await controller.change(
      (data) => data.archivePlan(plan.id, DateTime.now().toUtc()),
    );
    expect(requests, isEmpty);
    expect(controller.reminderCoverage, isNull);
  });

  test('native scheduling failure shows actual empty coverage and preserves entered plan', () async {
    permitted = true;
    failSchedule = true;
    await service.initialize();
    expect(controller.data.plans, hasLength(1));
    expect(controller.pendingReminders, 0);
    expect(controller.reminderCoverage, isNull);
    expect(controller.reminderWarning, 'schedule_failed');
  });

  test(
    'queued changed plan is reconciled even when the older pending query fails',
    () async {
      permitted = true;
      pendingBlocked = Completer<void>();
      failPending = true;
      final pending = service.initialize();
      while (!calls.contains('pendingNotificationRequests')) {
        await Future<void>.delayed(Duration.zero);
      }
      final plan = controller.data.plans.single;
      expect(
        await controller.change(
          (data) => data.archivePlan(plan.id, DateTime.now().toUtc()),
        ),
        isTrue,
      );
      pendingBlocked!.complete();
      await pending;
      expect(requests, isEmpty);
      expect(controller.pendingReminders, 0);
      expect(controller.reminderWarning, isNull);
      expect(
        calls.where((call) => call == 'cancelAllPendingNotifications').length,
        2,
      );
    },
  );

  test('shutdown waits for in-flight native scheduling before a new service can replace it', () async {
    permitted = true;
    blocked = Completer<void>();
    final pending = service.initialize();
    while (!calls.contains('zonedSchedule')) {
      await Future<void>.delayed(Duration.zero);
    }
    var stopped = false;
    final stopping = service.dispose().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    blocked!.complete();
    await pending;
    await stopping;
    expect(requests, hasLength(1));
    expect(controller.reconcile, isNull);
    expect(controller.requestReminders, isNull);
  });
}
