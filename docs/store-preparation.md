# Store preparation — draft only

Checked **2026-10-11**. Status **PREPARATION_ONLY**; no store account, credential, production lane or remote declaration was accessed. Existing `D:/AppPublishing/README.md` remains the only publishing protocol and contains the new `ilac-vakti` record. No new catalogue, schema or uploader was created.

Verified source facts: Android `com.xperspective.ilac_vakti`, iOS `com.xperspective.ilacVakti`, local `1.0.0+1`, Android target API36. These are source facts, not signed artifact/store identity or remote version proof. Native QA/build/CI evidence remains in this project's other evidence; metadata preparation does not accept those gates.

| Prepared content | Canonical directory |
|---|---|
| Play Turkish / English | `D:/AppPublishing/apps/ilac-vakti/stores/google-play/metadata/tr-TR` / `en-US` |
| App Store Turkish / English | `D:/AppPublishing/apps/ilac-vakti/stores/app-store/metadata/tr` / `en-US` |
| Legal draft | `D:/AppPublishing/apps/ilac-vakti/legal/privacy-policy.draft.md` |

26 nonempty localized text files were prepared: Play title, short/full description and `changelogs/1.txt`; iOS name/subtitle/description/keywords/promotional text/release notes/support/marketing/privacy URLs. Checked character limits: Play title conservatively30, short80, full4000, changelog500; iOS name/subtitle30, description4000, keywords100, promotion170. The legal draft is a SHA-256-equal copy of `docs/privacy-policy.md`. Existing different contents are refused, not overwritten. No screenshots were assigned or copied here.

Texts describe user-entered confirmed multi-person plans, encrypted local records, Taken/Skipped/Unrecorded corrections preserving audit, maximum64 upcoming generic notifications across all people within seven days, optional approximate Android timing, user-chosen password-protected backup and unverified editable local OCR drafts. They promise neither alarm delivery nor dosing/treatment advice, certain drug identification, cloud/email synchronization or absence of all SDK data/network activity.

The support URL `https://github.com/XPersPective/ilac-vakti/issues` and privacy URL `https://github.com/XPersPective/ilac-vakti/blob/main/docs/privacy-policy.md` are **draft references**. Actual availability, public privacy publication, support response process and publisher contact are unverified. Never upload draft/unreachable URLs or substitute another app's contact/account.

## Fresh official release gates

- [Google target API](https://developer.android.com/google/play/requirements/target-sdk): current new phone submissions/updates require API36 since31August2026. Verify the final merged AAB and behavior, not just Gradle source.
- [Health declaration](https://support.google.com/googleplay/android-developer/answer/14738291) and [health categories/guidance](https://support.google.com/googleplay/android-developer/answer/13996367): proposed functional classification is **Medication and Treatment Management**. Confirm the selected Console categories, actual intended users/claims, prominent camera disclosure/consent and required disclaimers. No medical-device clearance, clinical accuracy or legal certification is asserted.
- [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469): audit every final SDK/data flow and user-selected sharing. Local encrypted health records do not justify declaring the entire app collects no data. Actual Console answers/submission remain pending.
- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/): check1.4 health/safety,2.1 completeness/working URLs,2.3 truthful metadata and5.1 privacy/health data. No dosage calculator, HealthKit integration or default cloud health storage is claimed. Confirm publisher/legal/contact and actual device behavior separately.
- [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) and [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/): inspect the packaged app/transitive frameworks and applicable reasons/signatures; file presence does not certify compliance. Recheck [Apple SDK deadlines](https://developer.apple.com/news/upcoming-requirements/) against the actual submission archive.
- [ML Kit Android disclosure](https://developers.google.com/ml-kit/android-data-disclosure) and [iOS disclosure](https://developers.google.com/ml-kit/ios-data-disclosure): local text recognition can coexist with SDK device/app, installation and performance diagnostics. Reconcile final versions/configuration and platform-specific data categories. Do not claim no network/no collection based on on-device OCR.

Still pending: publisher and exact account/app mapping; remote records/version/build/track; final signed AAB/IPA and signing ownership; applicable testing/agreements; complete actual platform/locale/device screenshots; reachable finalized support/privacy URLs; age/target audience/health/privacy/permission declarations; and exact authorized upload/review/production destination. Native paths allow tools to consume secrets without printing them, but do not establish same-user AI isolation. Do not copy another app's keys. No readiness or legal guarantee is inferred from these drafts; recheck current requirements before each actual release.
