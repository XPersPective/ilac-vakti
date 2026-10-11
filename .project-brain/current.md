# Current Architecture
## Runtime
- Flutter3.47.2 / Dart3.13.2 independent Android/iOS app scaffold; package dependencies locked, no private source dependency.
## Map
- `lib/domain.dart` — immutable validated people/plans/revisions/occurrences/confirmation audit, explicit timezone scheduling.
- `lib/storage.dart` — authenticated two-slot device snapshots, native secure key, bounded password backup/import drafts.
- `test/domain_test.dart`, `test/storage_test.dart`, `test/domain_storage_test.dart` — meaningful domain, storage and integration regressions.
- `lib/ui.dart` — accessible TR/EN theme, Today/People/History/Settings, explicit plans and audit correction, optional OCR draft.
- `lib/controller.dart` — durable save before UI state, serialized mutation and sanitized error boundary.
- `lib/photo.dart` — bounded local Latin OCR draft with owned cache cleanup; `lib/main.dart` — fail-closed bootstrap.
- `android/`, `ios/` — generated scaffold; native hardening pending.
- `.project-brain/` — this app's own plan; `pubspec.lock` — public dependency graph.
## Domains
### app
Status: VERIFIED
Sources: `lib/**`, `test/**`, `android/**`, `ios/**`, `pubspec.yaml`, `docs/**`, `.github/**`, `publishing/**`
- Domain9/storage6/integration1/controller3/photo9/widget9 tests PASS (37 combined); final widget9 independently repeated, full fatal analyzer PASS.
- Daily DST gap skipped/fold first once, UTC-anchored intervals, confirmed entered plans only; archive/edit retain history and validated references.
- Device AES-GCM256, secure random key/nonce, flush alternating slots; missing/corrupt key fails closed. Backup Argon2id19MiB/2iterations + AES-GCM; validation precedes any replacement.
- Snapshot bounded1MiB, query366days/10000occurrences; UI/OCR draft implemented, native permissions/backup exclusion/share/reminder wiring pending. Today50-card pagination, history summary all selected occurrences with latest100 list explicitly labeled.
## Known Unknowns
- Store identity/signing/health declarations and physical-device acceptance remain release gates.
- Public standard GitHub macOS runner iOS simulator execution not yet performed; no private core dependency.
- Native KeyStore/Keychain behavior and actual power-loss recovery are not proved by synthetic file tests.
