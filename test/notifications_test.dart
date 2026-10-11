import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/domain.dart';
import 'package:ilac_vakti/notifications.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);
  test('clock rollback does not hide later unrecorded reminders behind recorded slots', () {
    final patient = Patient(name: 'Synthetic rollback');
    final plan = MedicinePlan(
      patientId: patient.id,
      name: 'Synthetic medicine',
      dose: 'Entered dose',
      confirmed: true,
      startUtc: now.add(const Duration(minutes: 1)),
      endUtc: now.add(const Duration(days: 1)),
      timeZone: 'Europe/Istanbul',
      intervalMinutes: 1,
    );
    var data = AppData(patients: [patient], plans: [plan]);
    for (final occurrence in plan.occurrences(
      plan.startUtc,
      now.add(const Duration(minutes: 66)),
    )) {
      data = data.record(
        occurrence,
        ConfirmationStatus.taken,
        now.add(const Duration(hours: 2)),
      );
    }
    final queue = upcomingReminders(data, now);
    expect(queue, hasLength(64));
    expect(queue.first.scheduledAtUtc, now.add(const Duration(minutes: 66)));
  });
  test(
    'future interval start inside horizon is not lost to a now-based bound',
    () {
      final patient = Patient(name: 'Synthetic future');
      final plan = MedicinePlan(
        patientId: patient.id,
        name: 'Synthetic medicine',
        dose: 'Entered dose',
        confirmed: true,
        startUtc: now.add(const Duration(days: 2)),
        endUtc: now.add(const Duration(days: 3)),
        timeZone: 'Europe/Istanbul',
        intervalMinutes: 1,
      );
      final queue = upcomingReminders(
        AppData(patients: [patient], plans: [plan]),
        now,
      );
      expect(queue, hasLength(64));
      expect(queue.first.scheduledAtUtc, plan.startUtc);
    },
  );
  test('all people share bounded earliest queue without patient or medicine payload', () {
    final people = [Patient(name: 'Synthetic A'), Patient(name: 'Synthetic B')];
    final plans = [
      for (final p in people)
        MedicinePlan(
          patientId: p.id,
          name: 'Synthetic medicine',
          dose: 'Entered dose',
          confirmed: true,
          startUtc: now.subtract(const Duration(hours: 1)),
          endUtc: now.add(const Duration(days: 30)),
          timeZone: 'Europe/Istanbul',
          intervalMinutes: 1,
        ),
    ];
    final queue = upcomingReminders(
      AppData(patients: people, plans: plans),
      now,
    );
    expect(queue, hasLength(64));
    expect(queue.map((o) => o.planId).toSet(), hasLength(2));
    expect(queue.every((o) => o.scheduledAtUtc.isAfter(now)), isTrue);
    expect(queue.every((o) => !o.id.contains('Synthetic')), isTrue);
    for (var i = 1; i < queue.length; i++) {
      expect(
        queue[i].scheduledAtUtc.isBefore(queue[i - 1].scheduledAtUtc),
        isFalse,
      );
    }
  });
  test(
    'closed plans do not produce stale reminders and horizon stays finite',
    () {
      final patient = Patient(name: 'Synthetic person');
      final plan = MedicinePlan(
        patientId: patient.id,
        name: 'Synthetic medicine',
        dose: 'Entered dose',
        confirmed: true,
        startUtc: now,
        endUtc: now.add(const Duration(days: 365)),
        timeZone: 'Europe/Istanbul',
        dailyMinutes: [600],
      );
      final data = AppData(patients: [patient], plans: [plan]);
      final queue = upcomingReminders(data, now);
      expect(queue, hasLength(7));
      expect(
        queue.last.scheduledAtUtc.isBefore(now.add(const Duration(days: 7))),
        isTrue,
      );
      expect(upcomingReminders(data.archivePlan(plan.id, now), now), isEmpty);
      expect(
        () => upcomingReminders(data, now, limit: 65),
        throwsFormatException,
      );
    },
  );
}
