import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import 'controller.dart';
import 'domain.dart';

class IlacVaktiApp extends StatefulWidget {
  const IlacVaktiApp({
    super.key,
    required this.controller,
    this.readPhoto,
    this.now,
    this.onExport,
    this.onImport,
  });
  final AppController controller;
  final Future<String?> Function()? readPhoto;
  final DateTime Function()? now;
  final Future<void> Function(String)? onExport;
  final Future<AppData?> Function(String)? onImport;
  @override
  State<IlacVaktiApp> createState() => _IlacVaktiAppState();
}

class _IlacVaktiAppState extends State<IlacVaktiApp> {
  ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff006b60),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff7f6f0)
          : scheme.surface,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final data = widget.controller.data;
      return MaterialApp(
        title: 'İlaç Vakti',
        debugShowCheckedModeBanner: false,
        locale: Locale(data.language),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: switch (data.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: _Home(options: widget),
      );
    },
  );
}

class _Home extends StatefulWidget {
  const _Home({required this.options});
  final IlacVaktiApp options;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  Timer? clockTimer;
  int page = 0, historyDays = 7;
  int todayPage = 0;
  String? person;
  bool externalBusy = false;
  @override
  void initState() {
    super.initState();
    if (widget.options.now == null) {
      clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    super.dispose();
  }

  AppController get c => widget.options.controller;
  AppData get data => c.data;
  DateTime get now => (widget.options.now?.call() ?? DateTime.now()).toUtc();
  String t(String tr, String en) => data.language == 'tr' ? tr : en;
  bool get busy => c.busy || externalBusy;
  String clock(DateTime date, String zone) {
    final local = tz.TZDateTime.from(date, locationForZone(zone));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String date(DateTime value, String zone) {
    final local = tz.TZDateTime.from(value, locationForZone(zone));
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<T?> settledDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
    final result = await Navigator.of(context).push(route);
    // Pop completes before the native reverse transition releases its text fields.
    await route.completed;
    return result;
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Vazgeç', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('Onayla', 'Confirm')),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> change(AppData Function(AppData) update) async {
    final ok = await c.change(update);
    notice(
      ok
          ? t('Kaydedildi', 'Saved')
          : t(
              'Kaydedilemedi. Kayıtlarınız değiştirilmedi.',
              'Could not save. Your records were preserved.',
            ),
    );
  }

  Future<void> patientForm([Patient? patient]) async {
    final text = TextEditingController(text: patient?.name ?? '');
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    await settledDialog<void>(
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            patient == null
                ? t('Kişi ekle', 'Add person')
                : t('Kişiyi düzenle', 'Edit person'),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('person-name'),
                    controller: text,
                    autofocus: true,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: t('Kişinin adı', 'Person name'),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? t('Bir ad girin', 'Enter a name')
                        : null,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: Text(t('Vazgeç', 'Cancel')),
            ),
            FilledButton(
              key: const Key('save-person'),
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialog(() {
                        saving = true;
                        error = null;
                      });
                      final ok = await c.change(
                        (d) => patient == null
                            ? d.addPatient(Patient(name: text.text))
                            : d.renamePatient(patient.id, text.text),
                      );
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(context);
                        notice(t('Kaydedildi', 'Saved'));
                      } else {
                        setDialog(() {
                          saving = false;
                          error = t(
                            'Kaydedilemedi. Yeniden deneyin.',
                            'Could not save. Try again.',
                          );
                        });
                      }
                    },
              child: Text(
                saving ? t('Kaydediliyor…', 'Saving…') : t('Kaydet', 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }

  Future<void> planForm(Patient patient, [MedicinePlan? plan]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _PlanEditor(
          controller: c,
          patient: patient,
          plan: plan,
          now: widget.options.now,
          readPhoto: widget.options.readPhoto,
        ),
      ),
    );
  }

  Widget heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          ),
      ],
    ),
  );
  Widget card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget filter() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('filter-$person-${data.patients.length}'),
      initialValue: person,
      decoration: InputDecoration(
        labelText: t('Kişi filtresi', 'Person filter'),
      ),
      isExpanded: true,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(t('Tüm kişiler', 'All people')),
        ),
        ...data.patients.map(
          (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
        ),
      ],
      onChanged: busy
          ? null
          : (value) => setState(() {
              person = value;
              todayPage = 0;
            }),
    ),
  );
  Widget today() {
    final instant = now;
    final local = tz.TZDateTime.from(instant, locationForZone(c.timeZone));
    final from = tz.TZDateTime(
      locationForZone(c.timeZone),
      local.year,
      local.month,
      local.day,
    ).toUtc();
    final to = tz.TZDateTime(
      locationForZone(c.timeZone),
      local.year,
      local.month,
      local.day + 1,
    ).toUtc();
    List<Occurrence> occurrences;
    try {
      occurrences = data.occurrences(from, to, patientId: person);
      todayPage = todayPage.clamp(
        0,
        occurrences.isEmpty ? 0 : (occurrences.length - 1) ~/ 50,
      );
    } on FormatException {
      return Column(
        children: [
          filter(),
          Text(
            t(
              'Bu aralık çok fazla kayıt içeriyor. Bir kişi seçin.',
              'Too many occurrences. Select one person.',
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          t('Bugün, adım adım', 'Today, one step at a time'),
          '${date(instant, c.timeZone)} · ${c.timeZone}',
        ),
        card([
          Text(
            clock(instant, c.timeZone),
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            t(
              'Yalnızca sizin onayladığınız planlar.',
              'Only the plans you have confirmed.',
            ),
          ),
        ]),
        if (data.patients.isEmpty)
          card([
            const Icon(Icons.people_outline, size: 40),
            const SizedBox(height: 16),
            Text(
              t(
                'İlk kişiyi ekleyerek başlayın',
                'Start by adding your first person',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () => patientForm(),
              icon: const Icon(Icons.person_add_outlined),
              label: Text(t('Kişi ekle', 'Add person')),
            ),
          ])
        else ...[
          filter(),
          if (occurrences.isEmpty)
            card([
              Text(
                t(
                  'Bugün için planlanmış ilaç yok.',
                  'No medicine scheduled for today.',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => page = 1),
                child: Text(t('Kişiler ve planlar', 'People and plans')),
              ),
            ]),
          // ponytail: bound rendered cards to50; use a lazy sliver if richer navigation is needed.
          ...occurrences
              .skip(todayPage * 50)
              .take(50)
              .map((o) => occurrenceCard(o, instant)),
          if (occurrences.length > 50)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${todayPage + 1} / ${(occurrences.length + 49) ~/ 50}'),
                OutlinedButton(
                  onPressed: todayPage == 0
                      ? null
                      : () => setState(() => todayPage--),
                  child: Text(t('Önceki kayıtlar', 'Previous records')),
                ),
                OutlinedButton(
                  onPressed: (todayPage + 1) * 50 >= occurrences.length
                      ? null
                      : () => setState(() => todayPage++),
                  child: Text(t('Sonraki kayıtlar', 'Next records')),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget occurrenceCard(Occurrence occurrence, DateTime instant) {
    final plan = data.plans.firstWhere(
      (p) => p.id == occurrence.planId && p.revision == occurrence.planRevision,
    );
    final patient = data.patients.firstWhere((p) => p.id == plan.patientId);
    final status = data.statusFor(occurrence.id);
    final future = occurrence.scheduledAtUtc.isAfter(instant);
    final label = status == ConfirmationStatus.taken
        ? t('Alındı', 'Taken')
        : status == ConfirmationStatus.skipped
        ? t('Atlandı', 'Skipped')
        : future
        ? t('Sıradaki plan', 'Upcoming')
        : t('Saati geçti · kayıt yok', 'Past scheduled time · unrecorded');
    return card([
      Text(
        '${clock(occurrence.scheduledAtUtc, plan.timeZone)} · ${patient.name}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(plan.name, style: Theme.of(context).textTheme.headlineSmall),
      Text(plan.dose),
      const SizedBox(height: 8),
      Text(plan.timeZone),
      const SizedBox(height: 12),
      Semantics(
        liveRegion: true,
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (!future)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy || status == ConfirmationStatus.taken
                    ? null
                    : () async {
                        if (status != null &&
                            !await confirm(
                              t('Kaydı düzelt', 'Correct record'),
                              t(
                                'Eski kayıt saklanır; yeni onay geçmişe eklenir.',
                                'The old record stays; your correction is added to history.',
                              ),
                            )) {
                          return;
                        }
                        await change(
                          (d) => d.record(
                            occurrence,
                            ConfirmationStatus.taken,
                            now,
                          ),
                        );
                      },
                icon: const Icon(Icons.check),
                label: Text(t('Alındı', 'Taken')),
              ),
              OutlinedButton(
                onPressed: busy || status == ConfirmationStatus.skipped
                    ? null
                    : () async {
                        if (!await confirm(
                          status == null
                              ? t('Atlandı olarak kaydet', 'Record as skipped')
                              : t('Kaydı düzelt', 'Correct record'),
                          t(
                            'Yalnızca gerçekten atlandıysa onaylayın. Önceki kayıt varsa saklanır.',
                            'Confirm only if it was skipped. Any previous record is preserved.',
                          ),
                        )) {
                          return;
                        }
                        await change(
                          (d) => d.record(
                            occurrence,
                            ConfirmationStatus.skipped,
                            now,
                          ),
                        );
                      },
                child: Text(t('Atlandı', 'Skipped')),
              ),
              if (status != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await confirm(
                            t('Kaydı geri al', 'Clear record'),
                            t(
                              'Durum yeniden kayıt yok olur. Eski onaylar denetim geçmişinde korunur.',
                              'The status becomes unrecorded. Previous confirmations remain in the audit history.',
                            ),
                          )) {
                            return;
                          }
                          await change(
                            (d) => d.record(
                              occurrence,
                              ConfirmationStatus.unrecorded,
                              now,
                            ),
                          );
                        },
                  child: Text(t('Kaydı geri al', 'Clear record')),
                ),
            ],
          ),
        ),
    ]);
  }

  Widget people() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        t('Birlikte takip edin', 'Care, together'),
        t(
          'Her kişinin planı ve geçmişi ayrı tutulur.',
          'Each person has separate plans and history.',
        ),
      ),
      FilledButton.icon(
        onPressed: busy ? null : () => patientForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(t('Kişi ekle', 'Add person')),
      ),
      const SizedBox(height: 24),
      ...data.patients.map(
        (patient) => card([
          Text(patient.name, style: Theme.of(context).textTheme.headlineSmall),
          if (patient.archived)
            Text(
              t(
                'Arşivlendi · geçmiş saklanıyor',
                'Archived · history preserved',
              ),
            ),
          if (!patient.archived)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => patientForm(patient),
                  child: Text(t('Adı düzenle', 'Rename')),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(
                            t('Kişiyi arşivle', 'Archive person'),
                            t(
                              'Planlar durdurulur; geçmiş silinmez.',
                              'Plans stop; history is preserved.',
                            ),
                          )) {
                            await change(
                              (d) => d.archivePatient(patient.id, now),
                            );
                          }
                        },
                  child: Text(t('Arşivle', 'Archive')),
                ),
              ],
            ),
          const SizedBox(height: 8),
          ...data
              .plansFor(patient.id)
              .where((p) => p.closedAtUtc == null)
              .map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(plan.dose),
                      Text(
                        plan.intervalMinutes == null
                            ? plan.dailyMinutes
                                  .map(
                                    (m) =>
                                        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
                                  )
                                  .join(' · ')
                            : t(
                                '${plan.intervalMinutes} dakikada bir',
                                'Every ${plan.intervalMinutes} minutes',
                              ),
                      ),
                      Text(
                        '${date(plan.startUtc, plan.timeZone)} – ${date(plan.endUtc, plan.timeZone)} · ${plan.timeZone}',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => planForm(patient, plan),
                            child: Text(t('Planı düzenle', 'Edit plan')),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (await confirm(
                                      t('Planı arşivle', 'Archive plan'),
                                      t(
                                        'Gelecek hatırlatmalar durur; geçmiş korunur.',
                                        'Future reminders stop; history is preserved.',
                                      ),
                                    )) {
                                      await change(
                                        (d) => d.archivePlan(plan.id, now),
                                      );
                                    }
                                  },
                            child: Text(t('Planı durdur', 'Stop plan')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          if (!patient.archived)
            OutlinedButton.icon(
              onPressed: busy ? null : () => planForm(patient),
              icon: const Icon(Icons.add),
              label: Text(t('İlaç planı ekle', 'Add medicine plan')),
            ),
        ]),
      ),
    ],
  );
  Widget history() {
    List<Occurrence> occurrences;
    final instant = now;
    try {
      occurrences = data.occurrences(
        instant.subtract(Duration(days: historyDays)),
        instant,
        patientId: person,
      );
    } on FormatException {
      return Column(
        children: [
          filter(),
          Text(
            t(
              'Bu aralık çok fazla kayıt içeriyor. Bir kişi seçin.',
              'Too many records in this range. Select one person.',
            ),
          ),
        ],
      );
    }
    final taken = occurrences
        .where((o) => data.statusFor(o.id) == ConfirmationStatus.taken)
        .length;
    final skipped = occurrences
        .where((o) => data.statusFor(o.id) == ConfirmationStatus.skipped)
        .length;
    final unrecorded = occurrences.length - taken - skipped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          t('Geçmiş görünür kalsın', 'Keep history in sight'),
          t(
            'Kayıt yok, ilacın atlandığı anlamına gelmez.',
            'Unrecorded does not mean a medicine was skipped.',
          ),
        ),
        filter(),
        Wrap(
          spacing: 12,
          children: [
            ChoiceChip(
              label: Text(t('7 gün', '7 days')),
              selected: historyDays == 7,
              onSelected: (_) => setState(() => historyDays = 7),
            ),
            ChoiceChip(
              label: Text(t('30 gün', '30 days')),
              selected: historyDays == 30,
              onSelected: (_) => setState(() => historyDays = 30),
            ),
          ],
        ),
        const SizedBox(height: 16),
        card([
          for (final entry in [
            (t('Alındı', 'Taken'), taken),
            (t('Atlandı', 'Skipped'), skipped),
            (t('Kayıt yok', 'Unrecorded'), unrecorded),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                label: '${entry.$1}: ${entry.$2}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${entry.$1} · ${entry.$2}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: occurrences.isEmpty
                            ? 0
                            : entry.$2 / occurrences.length,
                        minHeight: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
        ...occurrences.reversed
            .take(100)
            .map((o) => occurrenceCard(o, instant)),
        if (occurrences.length > 100)
          Text(
            t(
              'Özet tüm kayıtları, liste son 100 kaydı gösterir.',
              'Summary includes all records; list shows the latest 100.',
            ),
          ),
      ],
    );
  }

  Future<void> backup(bool importing) async {
    final password = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await settledDialog<bool>(
      builder: (context) => AlertDialog(
        title: Text(
          importing
              ? t('Yedeği aç', 'Open backup')
              : t('Şifreli yedek', 'Encrypted backup'),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t(
                    'En az 12 karakter. Bu şifreyi saklayın; unutulursa yedek açılamaz.',
                    'At least 12 characters. Keep this password; a forgotten password cannot be recovered.',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 256,
                  decoration: InputDecoration(
                    labelText: t('Yedek şifresi', 'Backup password'),
                  ),
                  validator: (value) => value == null || value.length < 12
                      ? t(
                          'En az 12 karakter girin',
                          'Enter at least 12 characters',
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(t('Devam', 'Continue')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      password.dispose();
      return;
    }
    setState(() => externalBusy = true);
    try {
      if (importing) {
        final draft = await widget.options.onImport!(password.text);
        if (draft != null &&
            mounted &&
            await confirm(
              t('Mevcut kayıtları değiştir?', 'Replace current records?'),
              t(
                'İçe aktarma mevcut kayıtların yerini alır. Önce mevcut verinizin şifreli yedeğini alın.',
                'Import replaces current records. Export an encrypted backup of your current records first.',
              ),
            )) {
          await change((_) => draft);
        }
      } else {
        await widget.options.onExport!(password.text);
        if (mounted) {
          notice(
            t(
              'Şifreli yedek paylaşım için hazırlandı.',
              'Encrypted backup prepared for sharing.',
            ),
          );
        }
      }
    } catch (_) {
      notice(
        t(
          'İşlem tamamlanamadı. Mevcut kayıtlarınız korunuyor.',
          'Could not complete the operation. Current records are preserved.',
        ),
      );
    } finally {
      password.clear();
      password.dispose();
      if (mounted) setState(() => externalBusy = false);
    }
  }

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(t('Size uygun takip', 'Care your way')),
      card([
        DropdownButtonFormField<String>(
          key: ValueKey('language-${data.language}'),
          initialValue: data.language,
          decoration: InputDecoration(labelText: t('Dil', 'Language')),
          items: const [
            DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: busy
              ? null
              : (v) => change((d) => d.preferences(language: v)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('theme-${data.theme}'),
          initialValue: data.theme,
          decoration: InputDecoration(labelText: t('Görünüm', 'Appearance')),
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(t('Sistem', 'System')),
            ),
            DropdownMenuItem(value: 'light', child: Text(t('Açık', 'Light'))),
            DropdownMenuItem(value: 'dark', child: Text(t('Koyu', 'Dark'))),
          ],
          onChanged: busy
              ? null
              : (v) => change((d) => d.preferences(theme: v)),
        ),
      ]),
      card([
        Text(
          t('Hatırlatmalar', 'Reminders'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'Bildirim teslimi garanti değildir. İzin, pil ve sistem sınırları etkileyebilir.',
            'Delivery is not guaranteed. Permissions, battery and system limits can affect reminders.',
          ),
        ),
        Text(
          t(
            'Bekleyen: ${c.pendingReminders} · ${c.exactReminders ? 'Kesin zaman izni var' : 'Kesin zaman izni doğrulanmadı'}',
            'Pending: ${c.pendingReminders} · ${c.exactReminders ? 'Exact permission available' : 'Exact permission not verified'}',
          ),
        ),
        if (c.reminderCoverage != null)
          Text(
            t(
              'Kapsama: ${date(c.reminderCoverage!, c.timeZone)} ${clock(c.reminderCoverage!, c.timeZone)} tarihine kadar',
              'Coverage through ${date(c.reminderCoverage!, c.timeZone)} ${clock(c.reminderCoverage!, c.timeZone)}',
            ),
          ),
        if (c.reminderWarning != null)
          Text(
            t(
              'Hatırlatmaların tümü kurulamadı. Sistem izinlerini kontrol edip uygulamayı yeniden açın.',
              'Some reminders could not be scheduled. Check system permissions and reopen the app.',
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : c.activateReminders,
          child: Text(
            t(
              'Bildirim izinlerini kontrol et',
              'Check notification permissions',
            ),
          ),
        ),
      ]),
      card([
        Text(
          t('Şifreli yedek', 'Encrypted backup'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy || widget.options.onExport == null
              ? null
              : () => backup(false),
          child: Text(t('Dışa aktar ve paylaş', 'Export and share')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy || widget.options.onImport == null
              ? null
              : () => backup(true),
          child: Text(t('Yedekten içe aktar', 'Import backup')),
        ),
      ]),
      card([
        Text(
          t('Hakkında ve gizlilik', 'About and privacy'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'İlaç Vakti, kullanıcı tarafından girilen planları takip eder; tıbbi öneri vermez. Sağlık kayıtları cihazda şifrelenir. Fotoğraflar ve metin cihazda işlenir; doğruluğunu siz kontrol edersiniz. Bulut eşitleme yoktur. OCR sağlayıcısı cihaz/uygulama ve performans tanılama verileri toplayabilir.',
            'İlaç Vakti tracks plans entered by you; it gives no medical advice. Health records are encrypted on the device. Photos and text are processed on-device for you to verify. There is no cloud sync. The OCR provider may collect device/app and performance diagnostic data.',
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'İlaç Vakti',
            applicationVersion: '1.0.0',
          ),
          child: Text(t('Açık kaynak lisansları', 'Open source licenses')),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(
                      ShareParams(
                        text: 'İlaç Vakti — https://github.com/XPersPective/ilac-vakti',
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  } catch (_) {
                    notice(t('Paylaşım açılamadı.', 'Could not open sharing.'));
                  }
                },
          child: Text(t('Uygulama projesini paylaş', 'Share app project')),
        ),
        Text(
          t(
            'Mağaza bağlantısı henüz yayımlanmadı. Paylaşım proje sayfasını açar.',
            'Store links are not published yet. Sharing opens the project page.',
          ),
        ),
      ]),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (person != null && !data.patients.any((p) => p.id == person)) {
      person = null;
    }
    final titles = [
      t('Bugün', 'Today'),
      t('Kişiler', 'People'),
      t('Geçmiş', 'History'),
      t('Ayarlar', 'Settings'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('İlaç Vakti')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (v) => setState(() => page = v),
        destinations: [
          for (final item in [
            (Icons.today_outlined, 0),
            (Icons.people_outline, 1),
            (Icons.bar_chart_outlined, 2),
            (Icons.settings_outlined, 3),
          ])
            NavigationDestination(icon: Icon(item.$1), label: titles[item.$2]),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (c.recovered)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  t(
                    'Son sağlam yedek kurtarıldı; en son değişiklik eksik olabilir.',
                    'Recovered the last intact snapshot; the latest change may be missing.',
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      switch (page) {
                        0 => today(),
                        1 => people(),
                        2 => history(),
                        _ => settings(),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    required this.controller,
    required this.patient,
    this.plan,
    this.now,
    this.readPhoto,
  });
  final AppController controller;
  final Patient patient;
  final MedicinePlan? plan;
  final DateTime Function()? now;
  final Future<String?> Function()? readPhoto;
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      dose,
      times,
      interval,
      start,
      duration,
      zone;
  bool elapsed = false, verified = false, busy = false, photoDraft = false;
  String? error;
  AppController get c => widget.controller;
  String t(String tr, String en) => c.data.language == 'tr' ? tr : en;
  DateTime get now => (widget.now?.call() ?? DateTime.now()).toUtc();
  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    final local = tz.TZDateTime.from(
      now.add(const Duration(minutes: 1)),
      locationForZone(p?.timeZone ?? c.timeZone),
    );
    name = TextEditingController(text: p?.name ?? '');
    dose = TextEditingController(text: p?.dose ?? '');
    times = TextEditingController(
      text:
          p?.dailyMinutes
              .map(
                (m) =>
                    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
              )
              .join(', ') ??
          '',
    );
    interval = TextEditingController(
      text: p?.intervalMinutes == null
          ? ''
          : (p!.intervalMinutes! / 60).toString(),
    );
    start = TextEditingController(
      text:
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    );
    duration = TextEditingController(text: '');
    zone = TextEditingController(text: p?.timeZone ?? c.timeZone);
    elapsed = p?.intervalMinutes != null;
  }

  @override
  void dispose() {
    for (final field in [name, dose, times, interval, start, duration, zone]) {
      field.dispose();
    }
    super.dispose();
  }

  List<int>? parseTimes(String text) {
    final chunks = text.split(',').map((s) => s.trim()).toList();
    final values = <int>[];
    for (final chunk in chunks) {
      final match = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$')
          .firstMatch(chunk);
      if (match == null) return null;
      values.add(int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!));
    }
    return values.length <= 48 && values.toSet().length == values.length
        ? values
        : null;
  }

  DateTime? parseStart() {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$')
        .firstMatch(start.text.trim());
    if (m == null) return null;
    try {
      final parts = List.generate(5, (i) => int.parse(m.group(i + 1)!));
      final local = tz.TZDateTime(
        locationForZone(zone.text.trim()),
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        parts[4],
      );
      if (local.year != parts[0] ||
          local.month != parts[1] ||
          local.day != parts[2] ||
          local.hour != parts[3] ||
          local.minute != parts[4]) {
        return null;
      }
      return local.toUtc();
    } catch (_) {
      return null;
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    String? hint,
    int max = 200,
    String? Function(String?)? validator,
    Key? key,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: key,
      controller: controller,
      enabled: !busy,
      onChanged: (_) {
        if (verified) setState(() => verified = false);
      },
      maxLength: max,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator:
          validator ??
          (v) => v == null || v.trim().isEmpty
              ? t('Bu alan gerekli', 'This field is required')
              : null,
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (!verified) {
      setState(
        () => error = t(
          'Planı kontrol ettiğinizi onaylayın.',
          'Confirm that you checked this plan.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final ok = await c.change((data) {
      final begin = parseStart()!;
      final days = int.parse(duration.text);
      final local = tz.TZDateTime.from(
        begin,
        locationForZone(zone.text.trim()),
      );
      final end = elapsed
          ? begin.add(Duration(days: days))
          : tz.TZDateTime(
              local.location,
              local.year,
              local.month,
              local.day + days,
              local.hour,
              local.minute,
            ).toUtc();
      final p = MedicinePlan(
        id: widget.plan?.id,
        patientId: widget.patient.id,
        name: name.text,
        dose: dose.text,
        confirmed: true,
        startUtc: begin,
        endUtc: end,
        timeZone: zone.text.trim(),
        dailyMinutes: elapsed ? [] : parseTimes(times.text)!,
        intervalMinutes: elapsed
            ? (double.parse(interval.text) * 60).round()
            : null,
        revision: (widget.plan?.revision ?? 0) + 1,
      );
      return widget.plan == null
          ? data.addPlan(p)
          : data.replacePlan(widget.plan!.id, p, now);
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Plan kaydedildi', 'Plan saved'))),
      );
    } else {
      setState(() {
        busy = false;
        error = t(
          'Kaydedilemedi. Başlangıç saatini ve alanları kontrol edin; kayıtlarınız korunuyor.',
          'Could not save. Check the start time and fields; your records are preserved.',
        );
      });
    }
  }

  Future<void> photo() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final text = await widget.readPhoto!();
      if (text != null && text.trim().isNotEmpty && mounted) {
        final line = text
            .split(RegExp(r'[\r\n]'))
            .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '')
            .trim();
        setState(() {
          name.text = line.length > 200 ? line.substring(0, 200) : line;
          photoDraft = true;
          verified = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Fotoğraf okunamadı. Elle girebilirsiniz.',
            'Could not read photo. You can enter the plan manually.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.plan == null
            ? t('İlaç planı ekle', 'Add medicine plan')
            : t('Planı düzenle', 'Edit plan'),
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.patient.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Reçetenizdeki veya sağlık uzmanınızın verdiği planı girin. Bu uygulama doz önermez.',
                    'Enter the plan from your prescription or health professional. This app does not recommend a dose.',
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.readPhoto != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : photo,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      t('Fotoğraftan taslak oku', 'Read draft from photo'),
                    ),
                  ),
                if (photoDraft)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      t(
                        'DOĞRULANMAMIŞ TASLAK — Metin yanlış olabilir. İlaç adını, dozu ve tüm saatleri kendiniz kontrol edin.',
                        'UNVERIFIED DRAFT — Text may be wrong. Check the medicine name, dose and every scheduled time yourself.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                field(
                  name,
                  t('İlaç adı', 'Medicine name'),
                  key: const Key('medicine-name'),
                ),
                field(
                  dose,
                  t('Kullanıcı tarafından girilen doz', 'Dose entered by you'),
                  key: const Key('medicine-dose'),
                ),
                DropdownButtonFormField<bool>(
                  initialValue: elapsed,
                  decoration: InputDecoration(
                    labelText: t('Plan türü', 'Schedule type'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(t('Günlük saatler', 'Daily times')),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(t('Sabit süreli aralık', 'Elapsed interval')),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          elapsed = v!;
                          verified = false;
                        }),
                ),
                const SizedBox(height: 16),
                if (!elapsed)
                  field(
                    times,
                    t('Günlük saatler (HH:mm)', 'Daily times (HH:mm)'),
                    hint: '08:00, 20:00',
                    key: const Key('daily-times'),
                    validator: (v) => parseTimes(v ?? '') == null
                        ? t(
                            'Benzersiz 24 saat biçimi kullanın: 08:00, 20:00',
                            'Use unique 24-hour times: 08:00, 20:00',
                          )
                        : null,
                  )
                else
                  field(
                    interval,
                    t('Kaç saatte bir?', 'Every how many hours?'),
                    key: const Key('interval-hours'),
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null ||
                              !n.isFinite ||
                              n * 60 < 1 ||
                              n * 60 > 525600 ||
                              (n * 60 - (n * 60).round()).abs() > 0.00001
                          ? t(
                              'Tam dakika veren geçerli bir süre girin',
                              'Enter a valid interval in whole minutes',
                            )
                          : null;
                    },
                  ),
                field(
                  zone,
                  t('Saat dilimi (IANA)', 'Time zone (IANA)'),
                  hint: 'Europe/Istanbul',
                  max: 100,
                  validator: (v) {
                    try {
                      locationForZone(v?.trim() ?? '');
                      return null;
                    } catch (_) {
                      return t(
                        'Geçerli IANA saat dilimi girin',
                        'Enter a valid IANA time zone',
                      );
                    }
                  },
                ),
                field(
                  start,
                  t('Başlangıç (YYYY-MM-DD HH:mm)', 'Start (YYYY-MM-DD HH:mm)'),
                  key: const Key('plan-start'),
                  max: 16,
                  validator: (v) => parseStart() == null
                      ? t(
                          'Geçerli yerel tarih/saat girin',
                          'Enter a valid local date/time',
                        )
                      : widget.plan != null && parseStart()!.isBefore(now)
                      ? t(
                          'Yeni plan başlangıcı gelecekte olmalı',
                          'The replacement must start in the future',
                        )
                      : null,
                ),
                field(
                  duration,
                  t('Süre (gün)', 'Duration (days)'),
                  key: const Key('plan-days'),
                  keyboard: TextInputType.number,
                  max: 3,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 365
                        ? t('1–365 gün girin', 'Enter 1–365 days')
                        : null;
                  },
                ),
                Text(
                  t(
                    'Günlük planda yaz saati boşluğu atlanır; tekrar eden saat bir kez kullanılır. Aralık planı başlangıca bağlı gerçek süreyi izler.',
                    'Daily plans skip nonexistent daylight-saving times and use repeated times once. Interval plans follow elapsed time from the start.',
                  ),
                ),
                CheckboxListTile(
                  key: const Key('plan-confirmed'),
                  contentPadding: EdgeInsets.zero,
                  value: verified,
                  onChanged: busy ? null : (v) => setState(() => verified = v!),
                  title: Text(
                    t(
                      'Adı, dozu, saatleri ve süreyi kontrol ettim.',
                      'I checked the name, dose, times and duration.',
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                FilledButton(
                  key: const Key('save-plan'),
                  onPressed: busy ? null : save,
                  child: Text(
                    busy
                        ? t('Kaydediliyor…', 'Saving…')
                        : t('Planı kaydet', 'Save plan'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
