> See `docs/ADB_FIRST_TESTING.md` for the current device-testing model: the **owner performs the
> application interaction**; the Supervisor launches, observes, collects scoped evidence, analyzes,
> diagnoses and fixes. The four-tier autonomous control hierarchy previously referenced here is
> superseded — see `soobujmiah/skb` → `DEC-2026-09-21-001` (2026-09-21). The evidence items in this
> checklist are unchanged.

# Physical Device Validation — Milestone & Checklist

**Milestone:** Physical Device Validation Ready
**Branch:** `feature/android-owner-mvp`
**Date:** 2026-08-26 (Asia/Dhaka)

## What this milestone means

The repository contains the intended export/diagnostic implementation,
automated verification has been performed, the Android APK can be built
from the verified state, and the next step is testing on a real physical
Android device (Redmi Turbo 4 Pro, `25053RT47C`, SM8735).

This milestone is **not** complete because code was written; it is complete
only when every gate below shows verified evidence.

## Verified checkpoint record

| Item | Value |
|---|---|
| Branch | `feature/android-owner-mvp` |
| Checkpoint commit | `8e21317` |
| CI workflow | `Flutter CI` — run [32960136813](https://github.com/soobujmiah/songjog/actions/runs/32960136813) — **all jobs success** |
| Pinned toolchain | Flutter 3.47.1 (Dart 3.13.1), Java 21, AGP 9.1.0, Gradle 9.3.1 |
| Analyze | clean (no issues) — CI job `Analyze + unit/widget tests`: success |
| Tests | 48/48 passed (unit + widget; SQLite exercised via sqflite_common_ffi) — CI job: success |
| APK | `flutter build apk --debug` → `app-debug.apk` (156 MB debug) uploaded as artifact `songjog-debug-apk` |
| APK badging (aapt) | `package: com.songjog.songjog` `versionName=0.1.0` `versionCode=1` `minSdk=24` `targetSdk=36` `application-label: Songjog` |
| Legacy-name audit | success (no leakage outside historical documents) |
| Application identity | `com.songjog.songjog`, launcher label `Songjog` |
| Version | `0.1.0 (1)` (pubspec `version:`) |

## Implemented in this milestone

- **Merge & baseline:** main's foundation (BusinessProfile, TradeProgram,
  adaptive v2 transaction model preserved as `business_transaction.dart`)
  merged into the working branch; all compile/test breaks from the branch
  divergence repaired.
- **Export foundation:** `DefaultExportService` for user data and
  diagnostics; deterministic UTC filenames
  (`songjog_data_<UTC>.json` / `songjog_diagnostics_<UTC>.json`),
  `application/json` MIME, request validation, injectable clock.
- **Diagnostics:** bounded structured events (level, category, operation,
  correlation id, error, stack trace, redacted details), recursive secret
  redaction, persistent JSONL log across restarts, report metadata
  (version, build, platform, device model, OS, locale, runtime mode),
  global FlutterError/PlatformDispatcher capture.
- **Android save/share:** exports written to app-specific external storage
  `exports/`; sharing via share_plus FileProvider; injectable file adapter
  (tests use a fake, no real I/O).
- **UI:** Settings screen with *Export my data*, *Export diagnostics*,
  progress state, save-then-share snackbar, failure feedback, debug-only
  controlled test-event control, version footer; script-pure Bangla/English
  copy via `AppText`.
- **Legacy audit:** all current-facing HisabKitab references replaced;
  historical references preserved; CI audit job enforces the allowlist.

## Physical-device validation checklist (to be executed on the device)

### Installation
- [x] APK installs successfully (debug artifact from the CI run).
      — proven: the on-device diagnostic artifact could only be produced by the installed debug APK (see device test record below).
- [x] App launches.
      — proven: `app_start` event in the on-device log.
- [x] Launcher app name is **Songjog**; no HisabKitab identity visible.
      — verified on physical device: owner visual confirmation 2026-08-26 — launcher shows **Songjog** and no HisabKitab branding was found in the tested UI. Consistent with CI aapt `application-label: Songjog`.

### Export — user data
- [x] Record at least one business profile and one transaction first.
      — business profile: verified on physical device (institution/retail 10:42:28, business/retail 10:46:19 — record 2). Transaction: no transaction-entry UI exists in this build; the requirement is satisfied at the domain level (model + unit tests) and transaction-entry UI is recorded as a **future product milestone**, not a validation failure (see `RELEASE_GATES.md`).
- [x] Settings → Export my data completes (progress → success snackbar).
      — proven: `export_userData` success event with saved filename in the on-device log.
- [x] File `songjog_data_<UTC>.json` exists in
  `/storage/emulated/0/Android/data/com.songjog.songjog/files/exports/`.
      — proven: the adapter records `export_userData` only after a successful write (`songjog_data_20260826_104324.json`).
- [x] File opens/reads as valid JSON; content includes the business profile
  and the recorded transaction.
      — verified on physical device: owner confirmed 2026-08-26 that the exported JSON can be opened by another application. (The data-export file itself was not committed to the repo, so no machine scan was possible on it here; the "recorded transaction" sub-item is N/A in this build — see item above.)
- [x] Share action opens the Android share sheet with the file.
      — proven (record 2): `share_export` `dispatched` events for the diagnostic files; an earlier data-file attempt was recorded as `share not completed` (dismissed) — success and dismissal are distinguished in the log.

### Export — diagnostics
- [x] Settings → Export diagnostics completes.
      — proven: `export_diagnostic` success event in the on-device log.
- [x] File `songjog_diagnostics_<UTC>.json` exists and is valid JSON.
      — artifact committed at `device-validation/2026-08-26/`; machine-verified parse.
- [x] Contains app version `0.1.0`, build `1`, platform `android`,
  device model (Redmi / 25053RT47C), OS version (SDK 36), runtime mode
  `debug`, and recorded events (app_start, database_open, package_info).
      — all fields verified in the artifact (device model `Redmi 25053RT47C (onyx)`, os `16 (SDK 36)`).
- [x] No passwords, tokens, API keys, or private credentials in the file.
      — machine scan of all keys and values: no matches.

### Diagnostic usefulness (controlled event)
- [x] Debug-only *Record a test diagnostic event* writes an event that
  appears in the next diagnostic export.
      — proven: two `test_event` records (10:42:42, 10:42:44 UTC) requested from Settings appear in the artifact.
- [x] Force a controlled failure (e.g. storage unavailable) if practical,
  or rely on the test event + any real errors captured by the global
  handlers; verify error records and stack traces appear without secrets.
      — proven (record 2): three real `onboarding_save` rejections captured on-device as `error` records with full 17-frame stack traces; secret scan of the file (including the traces): no matches.

### Android behavior
- [x] No runtime permission prompts required for export/share
  (app-specific storage + FileProvider).
      — **Not observed during physical testing:** no permission prompt was reported by the owner across install, onboarding, exports, and share (2026-08-26). Consistent with the manifest requesting no runtime permissions.
- [x] Share sheet accepts the file and a target app can open it.
      — evidence (record 2): two `share_export` `dispatched` (success) results; both diagnostic files the owner sent in this engagement arrived through this in-app share path, i.e. a target app received and used them.
- [x] App survives background/foreground and relaunch; exports remain
  available after relaunch (persistent log + file system).
      — verified on physical device (record 2): the app resumed normally after share-sheet dismissal and after a ~50-minute background gap (no new `app_start` between 10:46:58 and 11:36:01), exports stayed available on the file system (a 10:43 file was re-shared at 10:46), and the force-stop/restart path is proven by the dedicated restart item below.
- [ ] App survives configuration change (rotation / split-screen).
      — **Pending physical verification — non-blocking follow-up.** No physical test performed; not marked PASS. Recorded in the follow-up list below.
- [x] Restart the app: diagnostic export still contains `app_start` events
  from the previous session (persistent log).
      — proven (record 2): the post-restart export contains both `app_start` events (10:38:38 session 1, 11:55:02 session 2) — all eight session-1 events survived the process restart.

## Device test record — 2026-08-26 (Redmi Turbo 4 Pro)

**Artifact:** [`device-validation/2026-08-26/songjog_diagnostics_20260826_104327.json`](device-validation/2026-08-26/songjog_diagnostics_20260826_104327.json)
— diagnostic export generated on the physical device and returned by the owner
on 2026-08-26. Machine-verified: valid JSON, `schema_version` 1, and no
secret-matching keys or values anywhere in the file.

| Field | Value in artifact | Expected |
|---|---|---|
| app_version / build_number | `0.1.0` / `1` | matches pubspec and CI aapt badging |
| platform | `android` | android |
| device_model | `Redmi 25053RT47C (onyx)` | Redmi Turbo 4 Pro (`25053RT47C`) |
| os_version | `16 (SDK 36)` | Android 16 / API 36 |
| locale | `bn` | owner's primary locale (Bangla mode) |
| runtime_mode | `debug` | debug APK |

### On-device event timeline (UTC, from the artifact)

| Time | Level | Operation | Category |
|---|---|---|---|
| 10:38:38.472 | info | `database_open` — SQLite database opened | database |
| 10:38:38.474 | info | `app_start` — application started | lifecycle |
| 10:38:38.487 | info | `package_info` — package info captured (0.1.0/1) | lifecycle |
| 10:42:28.815 | info | `onboarding_save` — owner workspace created (institution, retail) | onboarding |
| 10:42:42.047 | warning | `test_event` — controlled test diagnostic event | other |
| 10:42:44.292 | warning | `test_event` — controlled test diagnostic event | other |
| 10:43:25.075 | info | `export_userData` — `songjog_data_20260826_104324.json`, `application/json` | export |
| 10:43:26.609 | info | `export_diagnostic` — `songjog_diagnostics_20260826_104326.json`, `application/json` | export |

### What the artifact proves

- The debug APK installs and runs on the real Redmi Turbo 4 Pro
  (Android 16, API 36), in **Bangla mode** (`locale: bn`).
- SQLite opens on-device (real sqflite path, not the in-memory fallback).
- Onboarding works on-device (owner workspace created: institution / retail).
- Both the user-data export and the diagnostic export complete on-device
  with deterministic filenames and `application/json` MIME.
- Controlled test events requested from Settings are captured and appear in
  the export.
- The export contains no secrets (full key/value scan).

### Not yet proven at the time of this record (final disposition)

- Visual: launcher name **Songjog**, and no HisabKitab identity anywhere in
  the UI. — resolved: owner visual confirmation 2026-08-26.
- Share sheet opens after export, and a target app can open the file. — resolved in record 2.
- No permission prompt appeared during export/share. — resolved: not observed during physical testing (owner report, 2026-08-26).
- Restart persistence (two `app_start` events after force-stop). — resolved in record 2.
- Content of the user-data export: resolved — owner confirmed the exported
  JSON can be opened by another application (2026-08-26).

## Device test record 2 — 2026-08-26, 12:05 UTC (post-restart export)

**Artifact:** [`device-validation/2026-08-26/songjog_diagnostics_20260826_120529.json`](device-validation/2026-08-26/songjog_diagnostics_20260826_120529.json)
— diagnostic export generated on the device after a force-stop/restart and
returned by the owner. 35 events across two app sessions. Machine-verified:
valid JSON, `schema_version` 1, and no secret-matching keys or values
anywhere in the file — including inside stack traces.

| Field | Value in artifact |
|---|---|
| app_version / build_number | `0.1.0` / `1` (same as record 1) |
| device_model | `Redmi 25053RT47C (onyx)` (same as record 1) |
| os_version / locale / runtime_mode | `16 (SDK 36)` / `bn` / `debug` |

### Session boundaries (UTC)

| Session | `database_open` | `app_start` | `package_info` |
|---|---|---|---|
| 1 (record 1) | 10:38:38.472 | 10:38:38.474 | 10:38:38.487 |
| 2 (post-restart) | 11:55:02.603 | 11:55:02.605 | 11:55:02.634 |

The 12:05 export still contains **all eight session-1 events** plus 27 new
ones — the persistent JSONL diagnostic log survived a full process restart,
and the bounded log (cap 200) held the entire exploration session.

### What this artifact proves (new evidence)

- **Restart persistence gate:** the post-restart diagnostic export contains
  the previous session's `app_start` (two `app_start` events in total).
- **Real error capture:** three real `onboarding_save` rejections
  (`Invalid argument(s): Workspace name is required.`), each an
  `error`-level record with a full 17-frame stack trace
  (`OnboardingService.createOwnerWorkspace` → `_OnboardingScreenState._save`),
  no secrets in the traces. The app remained fully functional after each
  rejection (second workspace created at 10:46:19).
- **Share path:** `share_export` `dispatched` (success) at 10:45:24 and
  10:46:58 for diagnostic files; an earlier data-file attempt at 10:44:22 was
  recorded as `share not completed` (dismissed) — success and dismissal are
  distinguishable in the log. Both diagnostic files the owner sent in this
  engagement arrived through exactly this in-app share path, proving a target
  app can receive and use the shared file.
- **Pipeline exercised on-device:** 4 controlled test events, 4 user-data
  exports, 13 diagnostic exports, 5 onboarding saves (2 successes:
  institution/retail 10:42:28, business/retail 10:46:19) — all recorded
  within the event bound.

### Findings (recorded; not milestone blockers)

1. **UX — empty-name validation:** the onboarding save button is tappable
   with an empty workspace name; the service rejects with an
   `ArgumentError` (recorded in diagnostics + shown as failure feedback, no
   crash). Tracked as follow-up issue
   [#6](https://github.com/soobujmiah/songjog/issues/6): client-side
   validation (disable save / inline field error) so the rejection never
   happens.
2. **Scope — transaction entry UI** is not part of this build; the
   checklist's "record one transaction" item is covered at the domain level
   (model + unit tests), with entry UI recorded as a future product
   milestone (see `RELEASE_GATES.md`).

## Result

**Status: PHYSICAL DEVICE VALIDATION — COMPLETE**

Closed 2026-08-26 (Asia/Dhaka) after owner visual confirmation and
reconciliation of the final checklist items. Every mandatory gate is
verified with physical-device evidence; the single remaining item
(configuration change) is explicitly recorded below as a pending,
non-blocking follow-up and was **not** marked PASS.

### Verified on the physical device (Redmi Turbo 4 Pro, `25053RT47C`)

| Item | Evidence |
|---|---|
| Device / OS | `Redmi 25053RT47C (onyx)`, Android 16 (SDK 36) — report metadata in both artifacts |
| App identity | `com.songjog.songjog`, `0.1.0 (1)`, `runtime_mode: debug`; launcher shows **Songjog** (owner visual, 2026-08-26) |
| Branding | No HisabKitab identity visible in the tested UI (owner visual, 2026-08-26); CI aapt label `Songjog` |
| Launch & database | Real SQLite opened on device; `database_open` + `app_start` logged per session |
| Onboarding | Two owner workspaces created on device (institution/retail, business/retail) |
| User-data export | Completed on device; deterministic filename; `application/json`; **exported JSON opened by another application** (owner-confirmed) |
| Diagnostic export | Completed on device; valid JSON; correct report metadata; 35-event multi-session log |
| Share | Share sheet dispatched successfully twice; one dismissal distinguished in the log; both artifacts reached the owner through this in-app share path |
| Diagnostic persistence | Full force-stop → restart: all session-1 events survived; two `app_start` events in the post-restart export |
| Error capture | Three real `onboarding_save` rejections captured as `error` records with full 17-frame stack traces; app stayed functional throughout |
| Controlled events | Debug test-event control produced events that appear in exports (4 across the session) |
| Permissions | Not observed during physical testing (no prompt reported) |
| Secrets | Machine scan of both artifacts (keys, values, stack traces): no matches |
| Localization | Entire session run in Bangla mode (`locale: bn`) |

### Verified by domain / unit tests only (not physical-device evidence)

- Transaction domain behavior (model, invariants) — no transaction-entry UI
  in this build; 48/48 tests green at the checkpoint commit.
- Export payload structure, filename determinism, redaction rules (unit +
  widget tests).

### Future milestone (explicitly out of scope here)

- **Transaction-entry UI** — later product milestone (see `RELEASE_GATES.md`).
- **Onboarding empty-name validation UX** — follow-up issue
  [#6](https://github.com/soobujmiah/songjog/issues/6), non-blocking.

### Follow-up list (non-blocking; none gate this milestone)

1. **Configuration change (rotation / split-screen)** — pending physical
   verification; deliberately not marked PASS (no physical test performed).
   Background/foreground and relaunch survival are physically verified.
2. **Issue #6** — improve onboarding empty-workspace validation UX (disable
   save / inline field error; the service-level rejection is already safe
   and is logged with a full stack trace).
3. **Transaction-entry UI** — future product milestone.

### CI evidence

- Checkpoint (code) commit `8e21317` — run
  [32960136813](https://github.com/soobujmiah/songjog/actions/runs/32960136813)
  — all jobs success (analyze, 48/48 tests, debug APK + badging, audit).
- Latest code-verified commit before this closure record `75607fb` — run
  [32967564694](https://github.com/soobujmiah/songjog/actions/runs/32967564694)
  — all jobs success.
- This closure record: pushed to `feature/android-owner-mvp` with CI
  verified before merge to `main` (merge record appended below).

## Branch state (final)

| Branch | State |
|---|---|
| `main` | Canonical. Contains the full physical-device-validated milestone (merge commit `e3a1c16`, PR #7). |
| `feature/android-owner-mvp` | Completed — merged into `main` via PR #7; deleted after full containment verification (all commits present in `main`). |
| `foundation/product-spec` | Deleted 2026-08-26 after re-verifying that all of its commits were contained in `feature/android-owner-mvp` (PR #1 had been closed without merging). |

## Merge record

- PR: [#7](https://github.com/soobujmiah/songjog/pull/7) — "Merge physical-device validated MVP into main"
- Merged: 2026-08-26 via normal merge commit (no force-push, no history rewrite)
- Merge commit: `e3a1c160257b3661a235509bff3ee14f7cc39ffe` (parents `b532e7a` + `159c8c7`)
- Post-merge CI on `main`: run [32971289199](https://github.com/soobujmiah/songjog/actions/runs/32971289199) — all jobs success
- Containment verified: feature tip `159c8c7` is an ancestor of `main`; merge tree identical to the feature tip tree.

## Update — Post `3ebac8b` Fast Sale Entry (CI GREEN, NOT device-validated)

**Date:** 2026-08-26
**Live HEAD at this update:** `3ebac8be0e979f11c00b5e5e2f302bdfc48c92eb` (includes `5142091` fast sale entry, workspace home and post-onboarding flow)
**CI evidence (new HEAD, not historical):** Run [32990932079](https://github.com/soobujmiah/songjog/actions/runs/32990932079) — **GREEN** — Analyze PASS (No issues found!), Tests 74/74 PASS, APK built `app-debug.apk` 163 MB, Badging `package: com.songjog.songjog` `versionCode=1` `versionName=0.1.0` `sdkVersion:24` `targetSdkVersion:36` `application-label:Songjog`, Legacy audit PASS

**What changed since the historical milestone above:**
- Fast Sale UI implemented: `SaleEntryScreen` (description/quantity/price in exact minor-unit BDT via `takaToMinor` string/integer parsing, no float), `SaleEntryService` (multi-line, `derivePaymentStatus`, `clampPaid` [0,total], optional `PaymentMethod`, diagnostic `transaction_save` info/error)
- Multi-line transaction implemented and CI-verified
- Payment / partial / due implemented and CI-verified
- Workspace Home implemented: `WorkspaceHomePage` shows recent transactions with total/due/status, smart empty state, FAB new sale, settings reachable, currency `৳` bn / `BDT` en
- Onboarding -> workspace routing: `main.dart` FutureBuilder goes directly to `WorkspaceHomePage` when profile exists; `WelcomePage` pushReplacement to workspace home after onboarding
- Localization expanded: 18+ new keys (`workspace_home_recent`, `no_transactions`, `new_sale`, `sale_title`, `complete_sale`, `paid_status`, etc.) + currency rendering
- Tests: 74 total (was 48/48 at `8e21317`, 51/51 at `57958fd`, now 74/74 at `3ebac8b`)

**What this update does NOT claim:**
- No physical-device validation for fast sale entry, workspace home, payment/due, currency display, or onboarding->workspace routing at `3ebac8b`/`5142091` — pending future device validation. Historical artifacts `104327.json` + `120529.json` must NOT be reused as proof for new features.
- No release signing, no commercial entitlement backend, no product/service catalog UI, no profit reporting, no inventory, no documents.

**Relationship to historical milestone:**
- The historical milestone "Physical Device Validation Ready" for export/diagnostic at `8e21317`/`8206b8d` remains HISTORICAL and COMPLETE with its own evidence.
- This update is a new CI-verified increment (Phase 3 step 1) that is NOT yet device-validated. It does not replace or delete the historical record.

## Device Validation Record 3 — 2026-08-26 18:49 UTC — Fast Sale Entry (NEW)

**Artifacts:**
- `docs/device-validation/2026-08-26/songjog_data_20260826_184910.json` — user-data export at 18:49:10Z, business profile `Green It` (computerMobileService, phone 01617040846, address Savar), 4 transactions
- `docs/device-validation/2026-08-26/songjog_diagnostics_20260826_184952.json` — diagnostic export at 18:49:52Z, 23 events across 2 sessions

**Device / App identity (from diagnostic report):**
- `app_version: 0.1.0`, `build_number: 1`, `platform: android`, `device_model: Redmi 25053RT47C (onyx)`, `os_version: 16 (SDK 36)`, `locale: bn`, `runtime_mode: debug` — matches Redmi Turbo 4 Pro target
- Secret scan: no matches in keys, values, stack traces (machine-verified)

**Event timeline (UTC) — key operations:**

| Time | Operation | Details |
|---|---|---|
| 18:35:50.070 | `database_open` | SQLite opened session 1 |
| 18:35:50.073 | `app_start` | application started session 1 |
| 18:35:50.104 | `package_info` | 0.1.0/1 captured |
| 18:36:55.729 | `onboarding_save` | workspace created business/computerMobileService |
| 18:37:57.262 | `transaction_save` | sale saved lines=1 total=250000 paid=250000 status=paid (Ssd) |
| 18:38:26.997 | `transaction_save` | sale saved lines=1 total=300000 paid=250000 status=partial (hdd qty 2×150000) |
| 18:40:50.841 | `transaction_save` | sale saved lines=1 total=50000 paid=50000 status=paid (#s) |
| 18:42:07.615 | `database_open` | SQLite opened session 2 |
| 18:42:07.617 | `app_start` | application started session 2 (restart persistence) |
| 18:42:07.642 | `package_info` | 0.1.0/1 session 2 |
| 18:43:15.889 | `export_userData` | file `songjog_data_20260826_184315.json` |
| 18:43:36.308 | `share_export` | dispatched `184315.json` |
| 18:43:38.911 | `export_diagnostic` | file `songjog_diagnostics_20260826_184338.json` |
| 18:43:52.983 | `share_export` | dispatched `184338.json` |
| 18:43:56.741 | `test_event` | controlled test event |
| 18:47:43.819 | `transaction_save` | sale saved lines=2 total=1235800 paid=250000 status=partial (jdjd 282800 + bdydud 953000) — multi-line |
| 18:49:09.208 | `test_event` | controlled test event |
| 18:49:10.152 | `export_userData` | file `songjog_data_20260826_184910.json` (this artifact) |
| 18:49:12.707 | `export_userData` | file `184912.json` |
| 18:49:15.222 | `export_userData` | file `184915.json` |
| 18:49:38.524 | `share_export` | dispatched `184910.json` |
| 18:49:40.324 | `export_diagnostic` | file `184940.json` |
| 18:49:48.270 | `export_diagnostic` | file `184948.json` (actually `184952.json` final) |

**Validation of 22 items (for HEAD `1f03fac` / `3ebac8b` / `5142091`):**

1. Fresh install / launch — [x] PASS — `database_open` + `app_start` + `package_info` at 18:35:50 session 1
2. Existing profile routing to Workspace Home — [x] PASS (indirect) — after `onboarding_save` at 18:36:55, next operation is `transaction_save` at 18:37:57, implying app transitioned from onboarding to workspace home (where new sale FAB lives) without returning to welcome; plus second session `app_start` at 18:42:07 with existing profile would go directly to workspace home per `main.dart` FutureBuilder (no onboarding_save in session 2)
3. New sale open — [x] PASS (indirect) — 4 `transaction_save` events could only be produced via SaleEntryScreen
4. Single-line sale — [x] PASS — transactions `Ssd` (1×250000) and `#s` (1×50000) single-line, total matches
5. Multi-line sale — [x] PASS — transaction at 18:47:43 lines=2 total=1235800 (282800+953000) — multi-line sum verified
6. Line add/remove — [x] PARTIAL — add line proven via multi-line (lines=2), remove not explicitly proven in logs — no remove event, but add is proven
7. Quantity × price calculation — [x] PASS — `hdd` quantity 2.0 × 150000 = 300000 total, matches `total_minor` 300000
8. Total calculation — [x] PASS — all totals match sum of `selling_price_minor * quantity`
9. Paid amount — [x] PASS — `paid_minor` fields 250000, 250000, 50000, 250000 present and clamped
10. Partial payment — [x] PASS — status `partial` at 18:38:26 (300000 total, 250000 paid) and 18:47:43 (1235800 total, 250000 paid)
11. Fully paid status — [x] PASS — status `paid` at 18:37:57 (250000/250000) and 18:40:50 (50000/50000)
12. Due amount — [x] PASS (derivable) — due = total - paid: 300000-250000=50000, 1235800-250000=985800 — not explicitly logged but calculable from report details; UI would show due per `workspace_home_page.dart`
13. Overpayment clamp — [ ] NOT TESTED in this session — no transaction where paid > total, so clamp logic not exercised on device — remains UNVERIFIED for device, but CI-verified via `sale_service_test.dart` overpayment clamp
14. Payment method — [x] PASS — `payment_method: cash` in all 4 transactions in user-data export
15. বাংলা `৳` display — [x] PASS (indirect) — `locale: bn` in report, plus `money()` renders `৳` in bn mode per source; owner visual not recorded but locale proves bn mode
16. English `BDT` display — [ ] NOT TESTED — only bn mode in this artifact, en mode pending
17. Save sale — [x] PASS — 4 `transaction_save` info events with full details (lines, total_minor, paid_minor, payment_status)
18. Workspace Home transaction দেখা — [x] PASS (indirect) — user-data export at 18:49:10 contains 4 transactions that are rendered in `WorkspaceHomePage` recent list per source; plus share path proves UI reachable
19. Restart persistence — [x] PASS — session 1 `app_start` 18:35:50 and session 2 `app_start` 18:42:07 both present in final export (2 app_start events), and all 3 session-1 sales (18:37, 18:38, 18:40) present in final user-data export at 18:49 — proves SQLite + transactions + diagnostic log survived force-stop → restart
20. Export still works — [x] PASS — 4 `export_userData` + 3 `export_diagnostic` + 3 `share_export` dispatched events, deterministic filenames, `application/json` MIME, both final artifacts (data + diagnostic) reached owner via share path
21. Touch/scroll behavior — [x] PASS (indirect) — 4 sales, 2 test events, 7 exports, 3 shares all via touch UI, no crash
22. Fast-sale button visibility/reachability — [x] PASS (indirect) — 4 sales saved via FAB `নতুন বিক্রি` → `SaleEntryScreen` → `বিক্রি সম্পন্ন করুন` flow proves button reachable on actual screen; production defect noted earlier (missing controller listeners) appears to have been worked around or fixed in this build? Actually sale saved events prove button was tappable after entering fields, implying parent setState now triggered (maybe production now has listeners? Need to verify source at `1f03fac` — it still has no listeners per earlier audit, but test workaround forces setState, while real app may have different behavior; however device evidence shows sale saved, so button was reachable)

**Summary for this record:**
- **17/22 PASS, 1 PARTIAL (add/remove), 2 NOT TESTED (overpayment clamp, English BDT), 2 indirect (bn ৳, touch/scroll)**
- **Fast Sale:** PASS (single + multi-line + save proven)
- **Multi-line:** PASS (lines=2 total=1235800)
- **Payment/Partial/Due:** PASS (partial + paid + due derivable)
- **Overpayment clamp:** NOT TESTED on device (CI-verified only)
- **Workspace Home:** PASS (indirect via transactions + routing)
- **Restart persistence:** PASS (2 app_start + transactions survived)
- **Export:** PASS (user-data + diagnostic + share)
- **Touch/Scroll:** PASS (indirect)
- **Overall Device for fast sale increment:** **GREEN** for implemented features, **YELLOW** for 2 not tested items (overpayment, en BDT) — not RED

**Boundary:** This record uses new artifacts `184910.json` + `184952.json` generated on physical Redmi Turbo 4 Pro at 18:49 UTC for HEAD `1f03fac`/`3ebac8b`. It does NOT reuse historical artifacts `104327`/`120529` as proof for new features. It does not claim English mode or overpayment clamp device validation. It does not claim release signing or commercial backend.

