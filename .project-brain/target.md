# Target Architecture
Status: CONFIRMED
## Goal
"ilaç takip uygulaması ... bir hasta bakıcının birden çok hastası ... ilaçları, günde kaç kez ... bildirim ... fotoğrafını çeker ... otomatik okur ... grafikler ... cloud'a bağlamak istemiyorum ... yeni bir tane repo ... D'de ayrı ... gerçekten üretim düzeyinde". User delegated implementation and source publication without repeated questions.
## Target State
### app
- Offline multi-person caregiver app; user-entered medicines, dose, daily/interval plans and duration; historical occurrence and recorded taken/skipped/unrecorded state.
- Encrypted durable device records and password-protected backup/import/share; optional local photo OCR drafts require user confirmation. No dosing/side-effect recommendation.
- Honest native notification permissions, finite iOS queue, timezone/reboot/resume behavior and coverage; no guaranteed alarm or background email sync.
- Accessible polished TR/EN light/dark interface, charts, About/license/share/privacy; no cloud/ad/paid feature enabled.
- Meaningful domain/storage/widget tests, fresh independent review, actual Android evidence and free-only unsigned iOS simulator build/screenshots; canonical publishing preparation.
## Non-Goals
- Clinical advice, drug identification certainty, automatic diagnosis/dosing, default cloud, silent email delivery, production store upload without verified identity/authorization.
- Publishing private shared source or real patient data to enable CI.
## Open Decisions
- Store app/account/signing identity and regulatory declarations remain release gates; they do not block offline development.
## Success Conditions
- Invalid plans and corrupted/tampered backups cannot replace records; persistence completes before success feedback.
- Multi-person plans/history survive restart and independent tests; notification limits are visible and no dose inferred.
- Android native use and public free-only iOS CI screenshot evidence retained; unsatisfied hardware/store acceptance explicitly recorded.
