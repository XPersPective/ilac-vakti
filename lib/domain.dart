import 'dart:convert';
import 'dart:math';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

String newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256),
  ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
}

Never _invalid() => throw const FormatException('Invalid medication data');
String _id(String value) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(value)) _invalid();
  return value;
}

String _text(String value, [int max = 200]) {
  if (value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    _invalid();
  }
  return value.trim();
}

DateTime _utc(DateTime value) {
  if (!value.isUtc || value.year < 1970 || value.year > 2200) _invalid();
  return value;
}

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    _invalid();
  }
  return value;
}

String _string(Object? value) => value is String ? value : _invalid();
int _int(Object? value) => value is int ? value : _invalid();
bool _bool(Object? value) => value is bool ? value : _invalid();
DateTime _date(Object? value) {
  final text = _string(value);
  if (!text.endsWith('Z')) _invalid();
  final parsed = DateTime.tryParse(text);
  if (parsed == null || parsed.toIso8601String() != text) _invalid();
  return _utc(parsed);
}

List<dynamic> _list(Object? value, int max) {
  if (value is! List || value.length > max) _invalid();
  return value;
}

bool _zonesReady = false;
tz.Location locationForZone(String name) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  if (name.length > 100) _invalid();
  try {
    return tz.getLocation(name);
  } catch (_) {
    return _invalid();
  }
}

class Patient {
  Patient({String? id, required String name, this.archived = false})
    : id = _id(id ?? newId()),
      name = _text(name, 100);
  final String id;
  final String name;
  final bool archived;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'archived': archived,
  };
  factory Patient.fromJson(Object? value) {
    final m = _map(value, {'id', 'name', 'archived'});
    return Patient(
      id: _string(m['id']),
      name: _string(m['name']),
      archived: _bool(m['archived']),
    );
  }
}

class MedicinePlan {
  MedicinePlan({
    String? id,
    required String patientId,
    required String name,
    required String dose,
    required this.confirmed,
    required DateTime startUtc,
    required DateTime endUtc,
    required this.timeZone,
    List<int> dailyMinutes = const [],
    this.intervalMinutes,
    this.revision = 1,
    DateTime? closedAtUtc,
  }) : id = _id(id ?? newId()),
       patientId = _id(patientId),
       name = _text(name),
       dose = _text(dose),
       startUtc = _utc(startUtc),
       endUtc = _utc(endUtc),
       closedAtUtc = closedAtUtc == null ? null : _utc(closedAtUtc),
       dailyMinutes = List.unmodifiable([...dailyMinutes]..sort()) {
    locationForZone(timeZone);
    if (!confirmed ||
        !endUtc.isAfter(startUtc) ||
        endUtc.difference(startUtc) > const Duration(days: 3660) ||
        revision < 1 ||
        revision > 1000000 ||
        (dailyMinutes.isEmpty == (intervalMinutes == null)) ||
        dailyMinutes.length > 48 ||
        dailyMinutes.toSet().length != dailyMinutes.length ||
        dailyMinutes.any((m) => m < 0 || m > 1439) ||
        (intervalMinutes != null &&
            (intervalMinutes! < 1 || intervalMinutes! > 525600)) ||
        (closedAtUtc != null && closedAtUtc.isAfter(endUtc))) {
      _invalid();
    }
  }
  final String id, patientId, name, dose, timeZone;
  final bool confirmed;
  final DateTime startUtc, endUtc;
  final DateTime? closedAtUtc;
  final List<int> dailyMinutes;
  final int? intervalMinutes;
  final int revision;
  String get key => '$id:$revision';
  DateTime get effectiveEnd =>
      closedAtUtc != null && closedAtUtc!.isBefore(endUtc)
      ? closedAtUtc!
      : endUtc;
  MedicinePlan close(DateTime atUtc) {
    _utc(atUtc);
    return MedicinePlan(
      id: id,
      patientId: patientId,
      name: name,
      dose: dose,
      confirmed: confirmed,
      startUtc: startUtc,
      endUtc: endUtc,
      timeZone: timeZone,
      dailyMinutes: dailyMinutes,
      intervalMinutes: intervalMinutes,
      revision: revision,
      closedAtUtc: atUtc.isBefore(endUtc) ? atUtc : endUtc,
    );
  }

  List<Occurrence> occurrences(
    DateTime fromUtc,
    DateTime toUtc, {
    int maxItems = 10000,
  }) {
    _window(fromUtc, toUtc, maxItems);
    final from = fromUtc.isAfter(startUtc) ? fromUtc : startUtc;
    final to = toUtc.isBefore(effectiveEnd) ? toUtc : effectiveEnd;
    if (!to.isAfter(from)) return [];
    final result = <Occurrence>[];
    void add(DateTime date) {
      if (date.isBefore(from) || !date.isBefore(to)) return;
      if (result.length == maxItems) _invalid();
      result.add(
        Occurrence(planId: id, planRevision: revision, scheduledAtUtc: date),
      );
    }

    if (intervalMinutes != null) {
      final step = Duration(minutes: intervalMinutes!).inMicroseconds;
      final elapsed = from.difference(startUtc).inMicroseconds;
      var date = startUtc.add(
        Duration(microseconds: ((elapsed + step - 1) ~/ step) * step),
      );
      while (date.isBefore(to)) {
        add(date);
        date = date.add(Duration(microseconds: step));
      }
    } else {
      final location = locationForZone(timeZone);
      final first = tz.TZDateTime.from(from, location);
      final last = tz.TZDateTime.from(to, location);
      var day = DateTime.utc(first.year, first.month, first.day);
      final lastDay = DateTime.utc(last.year, last.month, last.day);
      final offsets = location.zones.map((z) => z.offset).toSet();
      while (!day.isAfter(lastDay)) {
        for (final minute in dailyMinutes) {
          final wall = DateTime.utc(
            day.year,
            day.month,
            day.day,
            minute ~/ 60,
            minute % 60,
          );
          DateTime? earliest;
          for (final offset in offsets) {
            final candidate = wall.subtract(offset);
            final local = tz.TZDateTime.from(candidate, location);
            if (local.year == day.year &&
                local.month == day.month &&
                local.day == day.day &&
                local.hour == minute ~/ 60 &&
                local.minute == minute % 60 &&
                (earliest == null || candidate.isBefore(earliest))) {
              earliest = candidate;
            }
          }
          // A nonexistent wall time is skipped; a folded wall time occurs once, at its first instant.
          if (earliest != null) add(earliest);
        }
        day = day.add(const Duration(days: 1));
      }
    }
    result.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return List.unmodifiable(result);
  }

  bool contains(Occurrence occurrence) =>
      occurrence.planId == id &&
      occurrence.planRevision == revision &&
      occurrences(
        occurrence.scheduledAtUtc,
        occurrence.scheduledAtUtc.add(const Duration(microseconds: 1)),
        maxItems: 1,
      ).isNotEmpty;
  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'dose': dose,
    'confirmed': confirmed,
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
    'timeZone': timeZone,
    'dailyMinutes': dailyMinutes,
    'intervalMinutes': intervalMinutes,
    'revision': revision,
    'closedAtUtc': closedAtUtc?.toIso8601String(),
  };
  factory MedicinePlan.fromJson(Object? value) {
    final m = _map(value, {
      'id',
      'patientId',
      'name',
      'dose',
      'confirmed',
      'startUtc',
      'endUtc',
      'timeZone',
      'dailyMinutes',
      'intervalMinutes',
      'revision',
      'closedAtUtc',
    });
    return MedicinePlan(
      id: _string(m['id']),
      patientId: _string(m['patientId']),
      name: _string(m['name']),
      dose: _string(m['dose']),
      confirmed: _bool(m['confirmed']),
      startUtc: _date(m['startUtc']),
      endUtc: _date(m['endUtc']),
      timeZone: _string(m['timeZone']),
      dailyMinutes: _list(m['dailyMinutes'], 48).map(_int).toList(),
      intervalMinutes: m['intervalMinutes'] == null
          ? null
          : _int(m['intervalMinutes']),
      revision: _int(m['revision']),
      closedAtUtc: m['closedAtUtc'] == null ? null : _date(m['closedAtUtc']),
    );
  }
}

void _window(DateTime from, DateTime to, int maxItems) {
  _utc(from);
  _utc(to);
  if (!to.isAfter(from) ||
      to.difference(from) > const Duration(days: 366) ||
      maxItems < 1 ||
      maxItems > 10000) {
    _invalid();
  }
}

class Occurrence {
  Occurrence({
    required String planId,
    required this.planRevision,
    required DateTime scheduledAtUtc,
  }) : planId = _id(planId),
       scheduledAtUtc = _utc(scheduledAtUtc) {
    if (planRevision < 1 || planRevision > 1000000) _invalid();
  }
  final String planId;
  final int planRevision;
  final DateTime scheduledAtUtc;
  String get id =>
      '$planId:$planRevision:${scheduledAtUtc.microsecondsSinceEpoch}';
  factory Occurrence.fromId(String id) {
    final match = RegExp(r'^([a-f0-9]{32}):([1-9][0-9]{0,6}):([0-9]{1,16})$')
        .firstMatch(id);
    if (match == null) _invalid();
    final occurrence = Occurrence(
      planId: match.group(1)!,
      planRevision: int.parse(match.group(2)!),
      scheduledAtUtc: DateTime.fromMicrosecondsSinceEpoch(
        int.parse(match.group(3)!),
        isUtc: true,
      ),
    );
    if (occurrence.id != id) _invalid();
    return occurrence;
  }
}

enum ConfirmationStatus { taken, skipped, unrecorded }

class ConfirmationEvent {
  ConfirmationEvent({
    String? id,
    required this.occurrenceId,
    required this.status,
    required DateTime recordedAtUtc,
  }) : id = _id(id ?? newId()),
       recordedAtUtc = _utc(recordedAtUtc) {
    if (recordedAtUtc.isBefore(
      Occurrence.fromId(occurrenceId).scheduledAtUtc,
    )) {
      _invalid();
    }
  }
  final String id, occurrenceId;
  final ConfirmationStatus status;
  final DateTime recordedAtUtc;
  Map<String, dynamic> toJson() => {
    'id': id,
    'occurrenceId': occurrenceId,
    'status': status.name,
    'recordedAtUtc': recordedAtUtc.toIso8601String(),
  };
  factory ConfirmationEvent.fromJson(Object? value) {
    final m = _map(value, {'id', 'occurrenceId', 'status', 'recordedAtUtc'});
    final status = _string(m['status']);
    if (!ConfirmationStatus.values.any((s) => s.name == status)) _invalid();
    return ConfirmationEvent(
      id: _string(m['id']),
      occurrenceId: _string(m['occurrenceId']),
      status: ConfirmationStatus.values.byName(status),
      recordedAtUtc: _date(m['recordedAtUtc']),
    );
  }
}

class AppData {
  AppData({
    List<Patient> patients = const [],
    List<MedicinePlan> plans = const [],
    List<ConfirmationEvent> events = const [],
    this.revision = 0,
    this.language = 'tr',
    this.theme = 'system',
  }) : patients = List.unmodifiable(patients),
       plans = List.unmodifiable(plans),
       events = List.unmodifiable(events) {
    if (patients.length > 100 ||
        plans.length > 2000 ||
        events.length > 50000 ||
        revision < 0 ||
        revision > 2147483647 ||
        !['tr', 'en'].contains(language) ||
        !['system', 'light', 'dark'].contains(theme)) {
      _invalid();
    }
    final people = {for (final p in patients) p.id: p};
    final schedules = {for (final p in plans) p.key: p};
    if (people.length != patients.length ||
        schedules.length != plans.length ||
        events.map((e) => e.id).toSet().length != events.length) {
      _invalid();
    }
    final previous = <String, MedicinePlan>{};
    for (final plan in [
      ...plans,
    ]..sort((a, b) => a.revision.compareTo(b.revision))) {
      if (!people.containsKey(plan.patientId)) _invalid();
      final old = previous[plan.id];
      if (old == null
          ? plan.revision != 1
          : plan.revision != old.revision + 1 ||
                old.patientId != plan.patientId ||
                old.closedAtUtc == null ||
                plan.startUtc.isBefore(old.closedAtUtc!)) {
        _invalid();
      }
      if (people[plan.patientId]!.archived && plan.closedAtUtc == null) {
        _invalid();
      }
      previous[plan.id] = plan;
    }
    // ponytail: each immutable update validates the bounded full audit; use indexed
    // transactions if real records exceed this small offline snapshot model.
    final lastEvents = <String, ConfirmationEvent>{};
    for (final event in events) {
      final occurrence = Occurrence.fromId(event.occurrenceId);
      final plan = schedules['${occurrence.planId}:${occurrence.planRevision}'];
      if (plan == null || !plan.contains(occurrence)) _invalid();
      final old = lastEvents[event.occurrenceId];
      if (old == null && event.status == ConfirmationStatus.unrecorded) {
        _invalid();
      }
      if (old != null &&
          (event.recordedAtUtc.isBefore(old.recordedAtUtc) ||
              event.status == old.status)) {
        _invalid();
      }
      lastEvents[event.occurrenceId] = event;
    }
  }
  factory AppData.empty() => AppData();
  final List<Patient> patients;
  final List<MedicinePlan> plans;
  final List<ConfirmationEvent> events;
  final int revision;
  final String language, theme;
  AppData _next({
    List<Patient>? patients,
    List<MedicinePlan>? plans,
    List<ConfirmationEvent>? events,
  }) => AppData(
    patients: patients ?? this.patients,
    plans: plans ?? this.plans,
    events: events ?? this.events,
    revision: revision + 1,
    language: language,
    theme: theme,
  );
  AppData preferences({String? language, String? theme}) => AppData(
    patients: patients,
    plans: plans,
    events: events,
    revision: revision + 1,
    language: language ?? this.language,
    theme: theme ?? this.theme,
  );
  AppData addPatient(Patient patient) =>
      _next(patients: [...patients, patient]);
  AppData renamePatient(String id, String name) {
    if (!patients.any((p) => p.id == id)) _invalid();
    return _next(
      patients: patients
          .map(
            (p) => p.id == id
                ? Patient(id: id, name: name, archived: p.archived)
                : p,
          )
          .toList(),
    );
  }

  AppData archivePatient(String id, DateTime atUtc) {
    _utc(atUtc);
    if (!patients.any((p) => p.id == id)) _invalid();
    return _next(
      patients: patients
          .map(
            (p) =>
                p.id == id ? Patient(id: id, name: p.name, archived: true) : p,
          )
          .toList(),
      plans: plans
          .map(
            (p) =>
                p.patientId == id && p.closedAtUtc == null ? p.close(atUtc) : p,
          )
          .toList(),
    );
  }

  AppData addPlan(MedicinePlan plan) => _next(plans: [...plans, plan]);
  AppData replacePlan(String oldId, MedicinePlan replacement, DateTime atUtc) {
    _utc(atUtc);
    final matching = plans
        .where((p) => p.id == oldId && p.closedAtUtc == null)
        .toList();
    if (matching.length != 1 ||
        replacement.id != oldId ||
        replacement.closedAtUtc != null ||
        replacement.revision != matching.single.revision + 1 ||
        replacement.startUtc.isBefore(atUtc)) {
      _invalid();
    }
    return _next(
      plans: [
        ...plans.map((p) => identical(p, matching.single) ? p.close(atUtc) : p),
        replacement,
      ],
    );
  }

  AppData archivePlan(String id, DateTime atUtc) {
    _utc(atUtc);
    if (!plans.any((p) => p.id == id && p.closedAtUtc == null)) _invalid();
    return _next(
      plans: plans
          .map((p) => p.id == id && p.closedAtUtc == null ? p.close(atUtc) : p)
          .toList(),
    );
  }

  List<MedicinePlan> plansFor(String patientId) =>
      List.unmodifiable(plans.where((p) => p.patientId == patientId));
  ConfirmationStatus? statusFor(String occurrenceId) {
    for (final event in events.reversed) {
      if (event.occurrenceId == occurrenceId) {
        return event.status == ConfirmationStatus.unrecorded
            ? null
            : event.status;
      }
    }
    return null;
  }

  AppData record(
    Occurrence occurrence,
    ConfirmationStatus status,
    DateTime atUtc,
  ) {
    final event = ConfirmationEvent(
      occurrenceId: occurrence.id,
      status: status,
      recordedAtUtc: atUtc,
    );
    if (statusFor(occurrence.id) ==
        (status == ConfirmationStatus.unrecorded ? null : status)) {
      return this;
    }
    return _next(events: [...events, event]);
  }

  List<Occurrence> occurrences(
    DateTime fromUtc,
    DateTime toUtc, {
    String? patientId,
    int maxItems = 10000,
  }) {
    _window(fromUtc, toUtc, maxItems);
    final result = <Occurrence>[];
    for (final plan in plans.where(
      (p) => patientId == null || p.patientId == patientId,
    )) {
      result.addAll(plan.occurrences(fromUtc, toUtc, maxItems: maxItems));
      if (result.length > maxItems) _invalid();
    }
    result.sort((a, b) {
      final order = a.scheduledAtUtc.compareTo(b.scheduledAtUtc);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'revision': revision,
    'language': language,
    'theme': theme,
    'patients': patients.map((p) => p.toJson()).toList(),
    'plans': plans.map((p) => p.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
  };
  factory AppData.fromJson(Object? value) {
    final m = _map(value, {
      'schemaVersion',
      'revision',
      'language',
      'theme',
      'patients',
      'plans',
      'events',
    });
    if (m['schemaVersion'] != 1 || m['schemaVersion'] is! int) _invalid();
    final data = AppData(
      patients: _list(m['patients'], 100).map(Patient.fromJson).toList(),
      plans: _list(m['plans'], 2000).map(MedicinePlan.fromJson).toList(),
      events: _list(
        m['events'],
        50000,
      ).map(ConfirmationEvent.fromJson).toList(),
      revision: _int(m['revision']),
      language: _string(m['language']),
      theme: _string(m['theme']),
    );
    if (utf8.encode(jsonEncode(data.toJson())).length > 1024 * 1024) {
      _invalid();
    }
    return data;
  }
}
