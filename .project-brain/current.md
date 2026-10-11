# Current Architecture
## Runtime
- New independent Git repository; Flutter Android/iOS app not yet generated.
## Map
- `.project-brain/` — app-owned plan and checkpoints, no factory task copies.
- `AGENTS.md` — canonical Project Brain boot pointer.
## Domains
### app
Status: VERIFIED
Sources: `lib/**`, `test/**`, `android/**`, `ios/**`, `pubspec.yaml`, `docs/**`, `.github/**`, `publishing/**`
- No application code yet; Genesis records explicit user goal before implementation.
## Known Unknowns
- Store identity/signing/health declarations and physical-device acceptance require app-specific verification.
- Native iOS build will use public standard GitHub macOS runner with synthetic data; no private core dependency.
