import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'controller.dart';
import 'domain.dart';

/// Finite queue across all people. No background access to health records.
List<Occurrence> upcomingReminders(
  AppData data,
  DateTime now, {
  int limit = 64,
}) {
  if (!now.isUtc || limit < 1 || limit > 64) {
    throw const FormatException('Invalid reminder bound');
  }
  var selected = <Occurrence>[];
  final horizon = now.add(const Duration(days: 7));
  for (final plan in data.plans.where((p) => p.closedAtUtc == null)) {
    final interval = plan.intervalMinutes;
    final anchor = plan.startUtc.isAfter(now) ? plan.startUtc : now;
    final candidateEnd = interval == null
        ? horizon
        : anchor.add(Duration(minutes: interval * (limit + 1)));
    final end = candidateEnd.isBefore(horizon) ? candidateEnd : horizon;
    final candidates = <Occurrence>[];
    var from = now.add(const Duration(microseconds: 1));
    var until = end;
    do {
      candidates.addAll(
        plan
            .occurrences(from, until)
            .where((o) => data.statusFor(o.id) == null)
            .take(limit - candidates.length),
      );
      from = until;
      final next = until.add(
        Duration(minutes: (interval ?? 1440) * (limit + 1)),
      );
      until = next.isBefore(horizon) ? next : horizon;
    } while (interval != null &&
        candidates.length < limit &&
        from.isBefore(horizon) &&
        from.isBefore(plan.effectiveEnd));
    selected = [...selected, ...candidates]
      ..sort((a, b) {
        final order = a.scheduledAtUtc.compareTo(b.scheduledAtUtc);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    selected = selected.take(limit).toList();
  }
  return List.unmodifiable(selected);
}

class ReminderService with WidgetsBindingObserver {
  ReminderService(this.controller, {FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final AppController controller;
  final FlutterLocalNotificationsPlugin plugin;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;
  Completer<void>? _finished;

  Future<void> initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    controller.requestReminders = requestPermissions;
    controller.reconcile = (_) => reconcile();
    WidgetsBinding.instance.addObserver(this);
    await reconcile();
  }

  Future<bool> permitted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      controller.exactReminders =
          await android.canScheduleExactNotifications() ?? false;
      return await android.areNotificationsEnabled() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      controller.exactReminders = false;
      final options = await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!
          .checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      await android.requestNotificationsPermission();
      // Exact timing is optional; declining keeps the approximate route.
      if (await android.areNotificationsEnabled() == true) {
        await android.requestExactAlarmsPermission();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!
          .requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  Future<void> reconcile() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _finished = Completer<void>();
    try {
      do {
        _again = false;
        try {
          controller.reminderWarning = null;
          controller.reminderCoverage = null;
          controller.pendingReminders = 0;
          controller.remindersEnabled = await permitted();
          await plugin.cancelAllPendingNotifications();
          if (!controller.remindersEnabled) {
            controller.reminderWarning = 'permission_denied';
            continue;
          }
          final queue = upcomingReminders(
            controller.data,
            DateTime.now().toUtc(),
          );
          final tr = controller.data.language == 'tr';
          for (var index = 0; index < queue.length; index++) {
            if (_disposed) break;
            final occurrence = queue[index];
            try {
              await plugin.zonedSchedule(
                id: index,
                title: 'İlaç Vakti',
                body: tr
                    ? 'Planınızı kontrol etme zamanı.'
                    : 'Time to check your plan.',
                scheduledDate: tz.TZDateTime.from(
                  occurrence.scheduledAtUtc,
                  tz.UTC,
                ),
                notificationDetails: const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'plan_reminders_v1',
                    'Plan reminders',
                    importance: Importance.high,
                    priority: Priority.high,
                    visibility: NotificationVisibility.private,
                  ),
                  iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentSound: true,
                  ),
                ),
                androidScheduleMode: controller.exactReminders
                    ? AndroidScheduleMode.exactAllowWhileIdle
                    : AndroidScheduleMode.inexactAllowWhileIdle,
                payload: occurrence.id,
              );
            } catch (_) {
              controller.reminderWarning = 'schedule_failed';
              break;
            }
          }
          final actual = await plugin.pendingNotificationRequests();
          controller.pendingReminders = actual.length;
          final scheduled = queue
              .where((o) => actual.any((p) => p.payload == o.id))
              .toList();
          if (scheduled.isNotEmpty) {
            controller.reminderCoverage = scheduled.last.scheduledAtUtc;
          }
          if (actual.length != queue.length) {
            controller.reminderWarning = 'schedule_failed';
          }
        } catch (_) {
          controller.reminderWarning = 'reconcile_failed';
        }
      } while (_again && !_disposed);
    } finally {
      _running = false;
      _finished!.complete();
      if (!_disposed) controller.remindersChanged();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reconcile();
  }

  Future<void> dispose() async {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    controller.reconcile = null;
    controller.requestReminders = null;
    if (_running) await _finished!.future;
  }
}
