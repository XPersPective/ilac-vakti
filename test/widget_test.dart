import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_vakti/controller.dart';
import 'package:ilac_vakti/domain.dart';
import 'package:ilac_vakti/ui.dart';

final instant = DateTime.utc(2026, 10, 11, 12);
AppController controller([
  AppData? data,
  Future<void> Function(AppData)? save,
]) => AppController(
  initial: data ?? AppData.empty(),
  persist: save ?? (_) async {},
);
Future<void> launch(
  WidgetTester tester,
  AppController c, {
  Future<String?> Function()? photo,
}) async {
  await tester.pumpWidget(
    IlacVaktiApp(controller: c, now: () => instant, readPhoto: photo),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String value) async {
  final finder = find.text(value).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  if (!finder.hitTestable().evaluate().isNotEmpty) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

MedicinePlan existingPlan(Patient p) => MedicinePlan(
  patientId: p.id,
  name: 'Synthetic medicine',
  dose: 'Entered dose',
  confirmed: true,
  startUtc: DateTime.utc(2026, 10, 11),
  endUtc: DateTime.utc(2026, 10, 12),
  timeZone: 'Europe/Istanbul',
  dailyMinutes: [600],
);

void main() {
  testWidgets('GMT native controller renders after domain initialization', (
    tester,
  ) async {
    final patient = Patient(name: 'Synthetic GMT person');
    final plan = MedicinePlan(
      patientId: patient.id,
      name: 'Synthetic GMT medicine',
      dose: 'Entered dose',
      confirmed: true,
      startUtc: DateTime.utc(2026, 10, 11),
      endUtc: DateTime.utc(2026, 10, 12),
      timeZone: 'GMT',
      dailyMinutes: [600],
    );
    final c = AppController(
      initial: AppData(patients: [patient], plans: [plan]),
      persist: (_) async {},
      timeZone: 'GMT',
    );
    await launch(tester, c);
    expect(find.textContaining('Synthetic GMT person'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'overflow retains person filter so a smaller history can be selected',
    (tester) async {
      final dense = Patient(name: 'Synthetic dense');
      final small = Patient(name: 'Synthetic small');
      final start = instant.subtract(const Duration(days: 8));
      final end = DateTime.utc(2026, 10, 11);
      final c = controller(
        AppData(
          patients: [dense, small],
          plans: [
            MedicinePlan(
              patientId: dense.id,
              name: 'Synthetic interval',
              dose: 'Entered dose',
              confirmed: true,
              startUtc: start,
              endUtc: end,
              timeZone: 'Europe/Istanbul',
              intervalMinutes: 1,
            ),
            MedicinePlan(
              patientId: dense.id,
              name: 'Synthetic second interval',
              dose: 'Entered dose',
              confirmed: true,
              startUtc: start,
              endUtc: end,
              timeZone: 'Europe/Istanbul',
              intervalMinutes: 1,
            ),
            MedicinePlan(
              patientId: small.id,
              name: 'Synthetic daily',
              dose: 'Entered dose',
              confirmed: true,
              startUtc: start,
              endUtc: end,
              timeZone: 'Europe/Istanbul',
              dailyMinutes: [600],
            ),
          ],
        ),
      );
      await launch(tester, c);
      await tapText(tester, 'Geçmiş');
      expect(find.textContaining('çok fazla kayıt'), findsOneWidget);
      final filter = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      filter.onChanged!(small.id);
      await tester.pumpAndSettle();
      expect(find.textContaining('çok fazla kayıt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'replacing records clears a removed person filter on today and history',
    (tester) async {
      final first = Patient(name: 'Synthetic first');
      final second = Patient(name: 'Synthetic second');
      final c = controller(AppData(patients: [first]));
      await launch(tester, c);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      dropdown.onChanged!(first.id);
      await tester.pumpAndSettle();
      await c.change((_) => AppData(patients: [second]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tüm kişiler'), findsOneWidget);
      await tapText(tester, 'Geçmiş');
      expect(tester.takeException(), isNull);
      expect(find.text('Tüm kişiler'), findsOneWidget);
    },
  );
  testWidgets('empty state adds person and explicit confirmed daily plan', (
    tester,
  ) async {
    final c = controller();
    await launch(tester, c);
    expect(find.text('İlk kişiyi ekleyerek başlayın'), findsOneWidget);
    await tapText(tester, 'Kişi ekle');
    await fill(tester, 'person-name', 'Synthetic Person');
    await tapText(tester, 'Kaydet');
    expect(c.data.patients.single.name, 'Synthetic Person');
    await tapText(tester, 'Kişiler');
    await tapText(tester, 'İlaç planı ekle');
    await fill(tester, 'medicine-name', 'Synthetic medicine');
    await fill(tester, 'medicine-dose', 'Entered dose');
    await fill(tester, 'daily-times', '08:00, 20:00');
    await fill(tester, 'plan-days', '10');
    await tapText(tester, 'Planı kaydet');
    expect(c.data.plans, isEmpty);
    expect(find.text('Planı kontrol ettiğinizi onaylayın.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('plan-confirmed')));
    await tester.tap(find.byKey(const Key('plan-confirmed')));
    await tester.pump();
    await tapText(tester, 'Planı kaydet');
    expect(c.data.plans.single.dailyMinutes, [480, 1200]);
    expect(c.data.plans.single.confirmed, isTrue);
  });

  testWidgets(
    'person save waits for persistence and failure preserves editor and state',
    (tester) async {
      final gate = Completer<void>();
      final c = controller(null, (_) => gate.future);
      await launch(tester, c);
      await tapText(tester, 'Kişi ekle');
      await fill(tester, 'person-name', 'Synthetic Person');
      await tester.tap(find.byKey(const Key('save-person')));
      await tester.pump();
      expect(c.data.patients, isEmpty);
      expect(find.text('Kaydediliyor…'), findsOneWidget);
      expect(find.text('Kaydedildi'), findsNothing);
      gate.completeError(StateError('synthetic failure'));
      await tester.pumpAndSettle();
      expect(c.data.patients, isEmpty);
      expect(find.text('Kaydedilemedi. Yeniden deneyin.'), findsOneWidget);
      expect(find.text('Synthetic Person'), findsOneWidget);
      expect(find.textContaining('synthetic failure'), findsNothing);
    },
  );

  testWidgets('taken and correction append audit only after explicit action', (
    tester,
  ) async {
    final p = Patient(name: 'Synthetic Person');
    final c = controller(AppData(patients: [p], plans: [existingPlan(p)]));
    await launch(tester, c);
    expect(find.text('Saati geçti · kayıt yok'), findsOneWidget);
    await tapText(tester, 'Alındı');
    expect(c.data.events.single.status, ConfirmationStatus.taken);
    await tapText(tester, 'Atlandı');
    expect(c.data.events.length, 1);
    await tapText(tester, 'Onayla');
    expect(c.data.events.length, 2);
    expect(c.data.events.last.status, ConfirmationStatus.skipped);
    await tapText(tester, 'Kaydı geri al');
    await tapText(tester, 'Onayla');
    expect(c.data.events.length, 3);
    expect(c.data.events.last.status, ConfirmationStatus.unrecorded);
    expect(c.data.statusFor(c.data.events.last.occurrenceId), isNull);
    await tapText(tester, 'Geçmiş');
    expect(
      find.text('Kayıt yok, ilacın atlandığı anlamına gelmez.'),
      findsOneWidget,
    );
  });

  testWidgets('language and theme are persisted and applied', (tester) async {
    final c = controller();
    await launch(tester, c);
    await tapText(tester, 'Ayarlar');
    await tapText(tester, 'Türkçe');
    await tapText(tester, 'English');
    expect(c.data.language, 'en');
    expect(find.text('Settings'), findsOneWidget);
    await tapText(tester, 'System');
    await tapText(tester, 'Dark');
    expect(c.data.theme, 'dark');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.locale, const Locale('en'));
  });

  testWidgets(
    'OCR is editable unverified draft without automatic dose or confirmation',
    (tester) async {
      final p = Patient(name: 'Synthetic Person');
      final c = controller(AppData(patients: [p]));
      await launch(
        tester,
        c,
        photo: () async => 'OCR synthetic name\nPotentially wrong dose',
      );
      await tapText(tester, 'Kişiler');
      await tapText(tester, 'İlaç planı ekle');
      await tapText(tester, 'Fotoğraftan taslak oku');
      expect(find.textContaining('DOĞRULANMAMIŞ TASLAK'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('medicine-name')))
            .controller!
            .text,
        'OCR synthetic name',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('medicine-dose')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-confirmed')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('plan-confirmed')))
            .value,
        isFalse,
      );
      expect(c.data.plans, isEmpty);
    },
  );

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('large text and reduced motion fit $size without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final c = controller();
      await launch(tester, c);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Kişiler');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Ayarlar');
      expect(tester.takeException(), isNull);
    });
  }
}
