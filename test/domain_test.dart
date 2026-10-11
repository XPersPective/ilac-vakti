import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/domain.dart';

DateTime utc(String value) => DateTime.parse(value);
MedicinePlan plan(
  Patient patient, {
  String? id,
  int revision = 1,
  String zone = 'Europe/Berlin',
  List<int> daily = const [150],
  int? interval,
  String start = '2026-03-28T00:00:00Z',
  String end = '2026-03-31T00:00:00Z',
}) => MedicinePlan(
  id: id,
  patientId: patient.id,
  name: 'User entered',
  dose: 'User entered dose',
  confirmed: true,
  startUtc: utc(start),
  endUtc: utc(end),
  timeZone: zone,
  dailyMinutes: interval == null ? daily : [],
  intervalMinutes: interval,
  revision: revision,
);

void main() {
  test(
    'native GMT and legacy IANA aliases resolve without altering offsets',
    () {
      expect(locationForZone('GMT').currentTimeZone.offset, Duration.zero);
      expect(locationForZone('UTC').currentTimeZone.offset, Duration.zero);
      expect(locationForZone('US/Eastern').name, 'US/Eastern');
      final patient = Patient(name: 'Synthetic GMT person');
      final schedule = plan(patient, zone: 'GMT', daily: [150]);
      final first = schedule
          .occurrences(schedule.startUtc, schedule.endUtc)
          .first;
      expect(first.scheduledAtUtc, utc('2026-03-28T02:30:00Z'));
      expect(MedicinePlan.fromJson(schedule.toJson()).timeZone, 'GMT');
      expect(() => locationForZone('Missing/Zone'), throwsFormatException);
    },
  );

  test('clear accidental confirmation preserves audit without inventing a skipped dose', () {
    final patient = Patient(name: 'Synthetic person');
    final schedule = plan(patient, interval: 480);
    var data = AppData(patients: [patient], plans: [schedule]);
    final occurrence = schedule
        .occurrences(schedule.startUtc, schedule.endUtc)
        .first;
    data = data.record(occurrence, ConfirmationStatus.taken, schedule.startUtc);
    final cleared = data.record(
      occurrence,
      ConfirmationStatus.unrecorded,
      schedule.startUtc.add(const Duration(minutes: 1)),
    );
    expect(cleared.statusFor(occurrence.id), isNull);
    expect(cleared.events.map((event) => event.status), [
      ConfirmationStatus.taken,
      ConfirmationStatus.unrecorded,
    ]);
    expect(
      identical(
        cleared.record(
          occurrence,
          ConfirmationStatus.unrecorded,
          schedule.startUtc.add(const Duration(minutes: 2)),
        ),
        cleared,
      ),
      isTrue,
    );
    expect(AppData.fromJson(cleared.toJson()).statusFor(occurrence.id), isNull);
    expect(
      cleared
          .record(
            occurrence,
            ConfirmationStatus.skipped,
            schedule.startUtc.add(const Duration(minutes: 3)),
          )
          .statusFor(occurrence.id),
      ConfirmationStatus.skipped,
    );
  });
  test('close validates timestamp before clamping to plan end', () {
    final p = plan(Patient(name: 'A'));
    expect(() => p.close(DateTime(2300)), throwsFormatException);
    expect(() => p.close(DateTime.utc(2300)), throwsFormatException);
    expect(
      p.close(p.endUtc.add(const Duration(days: 1))).closedAtUtc,
      p.endUtc,
    );
  });

  test('backdated corrections and closures cannot remove recorded history', () {
    final patient = Patient(name: 'A');
    final p = plan(patient, interval: 720);
    final occurrence = p.occurrences(p.startUtc, p.endUtc)[1];
    final initial = AppData(patients: [patient], plans: [p]);
    final data = initial.record(
      occurrence,
      ConfirmationStatus.taken,
      occurrence.scheduledAtUtc.add(const Duration(minutes: 10)),
    );
    expect(
      () => data.record(
        occurrence,
        ConfirmationStatus.skipped,
        occurrence.scheduledAtUtc.add(const Duration(minutes: 5)),
      ),
      throwsFormatException,
    );
    expect(
      () => data.archivePlan(p.id, occurrence.scheduledAtUtc),
      throwsFormatException,
    );
    expect(data.plans.single.closedAtUtc, isNull);
    expect(data.events.length, 1);
    final invalidRevision = {
      ...data.toJson(),
      'plans': [
        {...p.toJson(), 'revision': 2},
      ],
    };
    expect(() => AppData.fromJson(invalidRevision), throwsFormatException);
  });

  test('daily skips DST gap and folds only once at first instant', () {
    final patient = Patient(name: 'A');
    final spring = plan(patient)
        .occurrences(utc('2026-03-28T00:00:00Z'), utc('2026-03-31T00:00:00Z'));
    expect(spring.map((o) => o.scheduledAtUtc), [
      utc('2026-03-28T01:30:00Z'),
      utc('2026-03-30T00:30:00Z'),
    ]);
    final autumn = plan(
      patient,
      start: '2026-10-24T00:00:00Z',
      end: '2026-10-27T00:00:00Z',
    ).occurrences(utc('2026-10-24T00:00:00Z'), utc('2026-10-27T00:00:00Z'));
    expect(autumn.map((o) => o.scheduledAtUtc), [
      utc('2026-10-24T00:30:00Z'),
      utc('2026-10-25T00:30:00Z'),
      utc('2026-10-26T01:30:00Z'),
    ]);
    expect(autumn.map((o) => o.id).toSet().length, 3);
  });

  test('elapsed interval stays anchored across DST with inclusive start/exclusive end', () {
    final p = plan(Patient(name: 'A'), interval: 720);
    final result = p.occurrences(p.startUtc, p.endUtc);
    expect(result.length, 6);
    expect(result.first.scheduledAtUtc, p.startUtc);
    expect(
      result.last.scheduledAtUtc,
      p.endUtc.subtract(const Duration(hours: 12)),
    );
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i].scheduledAtUtc.difference(result[i - 1].scheduledAtUtc),
        const Duration(hours: 12),
      );
    }
  });

  test('person separation, audit corrections, idempotence and roundtrip', () {
    final a = Patient(name: 'A'), b = Patient(name: 'B');
    final p = plan(a, interval: 720), q = plan(b, interval: 1440);
    var data = AppData(patients: [a, b], plans: [p, q]);
    final occurrence = data
        .occurrences(p.startUtc, p.endUtc, patientId: a.id)
        .first;
    expect(data.plansFor(b.id).single.id, q.id);
    expect(
      data
          .occurrences(p.startUtc, p.endUtc, patientId: a.id)
          .every((o) => o.planId == p.id),
      isTrue,
    );
    final futureBefore = data
        .occurrences(p.startUtc, p.endUtc)
        .map((o) => o.id)
        .toList();
    data = data.record(
      occurrence,
      ConfirmationStatus.taken,
      occurrence.scheduledAtUtc,
    );
    expect(
      identical(
        data.record(
          occurrence,
          ConfirmationStatus.taken,
          occurrence.scheduledAtUtc,
        ),
        data,
      ),
      isTrue,
    );
    data = data.record(
      occurrence,
      ConfirmationStatus.skipped,
      occurrence.scheduledAtUtc.add(const Duration(minutes: 2)),
    );
    expect(data.events.length, 2);
    expect(data.statusFor(occurrence.id), ConfirmationStatus.skipped);
    expect(
      data.occurrences(p.startUtc, p.endUtc).map((o) => o.id),
      futureBefore,
    );
    expect(
      AppData.fromJson(jsonDecode(jsonEncode(data.toJson()))).toJson(),
      data.toJson(),
    );
    expect(() => data.patients.add(a), throwsUnsupportedError);
  });

  test('replacement and archive preserve historical references', () {
    final a = Patient(name: 'A');
    final p = plan(a, interval: 720);
    var data = AppData(patients: [a], plans: [p]);
    final first = data.occurrences(p.startUtc, p.endUtc).first;
    data = data.record(first, ConfirmationStatus.taken, first.scheduledAtUtc);
    final editAt = utc('2026-03-29T00:00:00Z');
    final replacement = plan(
      a,
      id: p.id,
      revision: 2,
      interval: 1440,
      start: editAt.toIso8601String(),
    );
    data = data.replacePlan(p.id, replacement, editAt);
    expect(data.plans.length, 2);
    expect(data.plans.first.closedAtUtc, editAt);
    expect(data.statusFor(first.id), ConfirmationStatus.taken);
    final occurrences = data.occurrences(p.startUtc, p.endUtc);
    expect(occurrences.map((o) => o.planRevision), [1, 1, 2, 2]);
    data = data.archivePatient(a.id, utc('2026-03-30T00:00:00Z'));
    expect(data.patients.single.archived, isTrue);
    expect(data.events.length, 1);
    expect(data.plans.every((p) => p.closedAtUtc != null), isTrue);
    expect(
      AppData.fromJson(data.toJson()).events.single.id,
      data.events.single.id,
    );
  });

  test('rejects unsafe schema, references, unconfirmed drafts and invalid schedules', () {
    final a = Patient(name: 'A'), p = plan(Patient(name: 'B'));
    expect(() => AppData(patients: [a], plans: [p]), throwsFormatException);
    expect(() => AppData(patients: [a, a]), throwsFormatException);
    expect(() => Patient(id: '../unsafe', name: 'A'), throwsFormatException);
    expect(() => Patient(name: 'A\nB'), throwsFormatException);
    final valid = plan(a);
    for (final change in <Map<String, dynamic>>[
      {'confirmed': false},
      {
        'dailyMinutes': [1440],
      },
      {
        'dailyMinutes': [150, 150],
      },
      {'dailyMinutes': [], 'intervalMinutes': null},
      {'intervalMinutes': 60},
      {'timeZone': 'Missing/Zone'},
      {'startUtc': '2026-02-30T00:00:00.000Z'},
    ]) {
      expect(
        () => MedicinePlan.fromJson({...valid.toJson(), ...change}),
        throwsFormatException,
      );
    }
    expect(
      () => AppData.fromJson({...AppData.empty().toJson(), 'schemaVersion': 2}),
      throwsFormatException,
    );
    expect(
      () => AppData.fromJson({...AppData.empty().toJson(), 'unknown': true}),
      throwsFormatException,
    );
    final occurrence = valid.occurrences(valid.startUtc, valid.endUtc).first;
    expect(
      () => AppData(patients: [a], plans: [valid]).record(
        occurrence,
        ConfirmationStatus.taken,
        occurrence.scheduledAtUtc.subtract(const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
    final invented = Occurrence(
      planId: valid.id,
      planRevision: 1,
      scheduledAtUtc: valid.startUtc,
    );
    expect(
      () => AppData(
        patients: [a],
        plans: [valid],
      ).record(invented, ConfirmationStatus.taken, valid.startUtc),
      throwsFormatException,
    );
  });

  test('bounded generation fails instead of silently truncating', () {
    final p = plan(Patient(name: 'A'), interval: 1);
    expect(
      () => p.occurrences(p.startUtc, p.endUtc, maxItems: 2),
      throwsFormatException,
    );
    expect(
      () =>
          p.occurrences(p.startUtc, p.startUtc.add(const Duration(days: 367))),
      throwsFormatException,
    );
    expect(
      () => AppData(patients: List.generate(101, (_) => Patient(name: 'A'))),
      throwsFormatException,
    );
    final a = Patient(name: 'A');
    final x = plan(a, interval: 1440), y = plan(a, interval: 1440);
    expect(
      () => AppData(
        patients: [a],
        plans: [x, y],
      ).occurrences(x.startUtc, x.endUtc, maxItems: 4),
      throwsFormatException,
    );
  });
}
