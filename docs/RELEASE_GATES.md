# Release Gates

A feature is not release-ready because its documentation exists. It must pass the applicable implementation, test and product gates.

## Gate 1 — Foundation

- [x] Local durable database implemented — `SqliteStore` (schema v2), verified by `sqlite_store_test.dart` via sqflite_common_ffi (2026-08-26); re-verified at `3ebac8b` via CI `32990932079` (74/74 tests)
- [ ] Business/workspace scoping enforced
- [ ] Migration strategy tested (v1→v2 upgrade path exists in code; no upgrade test yet)
- [x] Offline transaction persistence tested — profile + multi-line transactions persist across store reopen (2026-08-26); re-verified at `3ebac8b` via `sqlite_store_test.dart` + `sale_service_test.dart` persistence

## Gate 2 — Owner onboarding

- [ ] Google/email authentication implemented
- [x] Owner profile/business creation implemented — `OnboardingService.createOwnerWorkspace` + `BusinessProfile` (business/institution, 12 BusinessTypes), verified by `onboarding_screen_test.dart`, CI `32990932079` (74/74)
- [ ] Business type selection implemented (dropdown exists, adaptive dashboard not yet)
- [x] Minimal mandatory fields verified — workspace name required, save disabled while empty/whitespace-only (`ValueListenableBuilder`), service-level guard preserved, verified by `onboarding_screen_test.dart`, CI `32980204789` and `32990932079`
- [x] Optional fields remain optional — phone, address, subtype optional, verified by `onboarding_service.dart` + `workspace_fields.dart`

## Gate 3 — Daily operations

- [ ] Product/service creation
- [x] Fast sale — `SaleEntryScreen` + `SaleEntryService` (description/quantity/price in exact minor-unit BDT via `takaToMinor` string/integer parsing, no float, reactive listeners for description/quantity/price/paid via `initState` + `_attachLineListeners` + `_onFieldChanged` setState), **returnable/change** (`calculateReturnable` = entered - total when overpaid, clamped paid stored, due 0, status paid, never store excess as revenue), verified by `sale_service_test.dart` (takaToMinor, minorToTaka, derivePaymentStatus, clampPaid, calculateReturnable, toBanglaDigits) + `sale_entry_screen_test.dart` widget flows (offstage-safe Finder skipOffstage:false + ensureVisible + enterField + tapCompleteSale, returnable UI, Bangla numerals), CI `33006998608` (92/92 PASS at `9e25997`), APK badging `com.songjog.songjog` `0.1.0` `24/36` `Songjog`, **device-validated at `ddce6f7` via Record 3 artifacts `184910.json` (4 sales) + `184952.json` (23 events, 2 sessions, Redmi 25053RT47C) — 17/22 PASS for fast sale core, returnable + Bangla numerals + locale toggle pending device validation**
- [x] Multi-line transaction — `SaleEntryService.saveSale` accepts `List<({description, quantity, priceMinor})>`, total = sum `lineTotalMinor`, verified by `sale_service_test.dart` multi-line totals (180000) + `sale_entry_screen_test.dart` multi-line widget test, CI `33006998608` (92/92), **device-validated at `ddce6f7` via multi-line sale lines=2 total=1235800 (282800+953000) in diagnostic `184952.json` + user-data `184910.json`**
- [x] Payment / partial payment / due + Returnable — `derivePaymentStatus` (unpaid/partial/paid, zero total never paid), `clampPaid` [0,total] prevents silent overpayment, `calculateReturnable` = entered - total when overpaid, due = total - clampedPaid, returnable UI (`returnable` + `change_due` keys, ৳ + Bangla numerals in bn), optional `PaymentMethod`, UI shows paid/partial/unpaid + due + returnable when >0, verified by `sale_service_test.dart` (clamp + returnable) + `sale_entry_screen_test.dart` (partial, paid, overpayment clamped + returnable UI), CI `33006998608` (92/92), **device-validated at `ddce6f7`: partial (300000/250000) + paid (250000/250000, 50000/50000) + due derivable + payment_method cash in `184910.json` + `184952.json`; overpayment returnable NOT yet device-validated (CI-verified only)**
- [ ] Private actual cost and profit
- [ ] Customer/service recipient
- [ ] Purchase/expense
- [ ] Return/refund/adjustment

## Gate 4 — Documents

- [ ] Receipt generation
- [ ] Multi-page pagination
- [ ] PDF/share/print
- [ ] Customer-facing privacy checks
- [ ] Document numbering and audit trail

## Gate 5 — Reporting

- [ ] Daily
- [ ] Monthly
- [ ] Yearly
- [ ] Profit
- [ ] Due
- [ ] Expense
- [ ] Cash reconciliation
- [x] Export — user-data export (`UserDataExport` deterministic UTC filenames, `application/json`) + diagnostic export (`DiagnosticCollector`, redaction, persistent JSONL) implemented, verified by `export_service_test.dart`, `user_data_export_test.dart`, `diagnostic_*_test.dart`, `local_export_file_adapter_test.dart`, `persistent_diagnostic_log_test.dart`, and historically device-validated on Redmi Turbo 4 Pro (artifacts `songjog_diagnostics_20260826_104327.json` + `120529.json`, no secrets, share sheet dispatched, restart persistence); re-verified CI `32990932079` (74/74)

## Gate 6 — Commercial control

- [ ] Trial entitlement
- [ ] Subscription entitlement
- [ ] One-time activation redemption
- [ ] Platform Owner role
- [ ] Revoke/restore
- [ ] Reinstall/device recovery
- [ ] No production secrets in source/APK

## Gate 7 — Localization and UX

- [x] Bengali UI script-purity audit — `AppText` bn values contain no Latin letters except placeholders like `{count}` (verified by `app_text_test.dart` script purity test with placeholder stripping), CI `33006998608` (92/92)
- [x] English UI script-purity audit — `AppText` en values contain no Bengali script (verified by `app_text_test.dart`), CI `33006998608`
- [x] No missing strings — bn keys 66, en keys 66, all present in both locales (verified by `app_text_test.dart` all keys present + new keys returnable/change_due/language), CI `33006998608`
- [x] Loading/empty/error/offline states — workspace home smart empty state (`no_transactions` + hint), loading spinner, sale entry error snackbar `sale_failed`, settings busy indicator, verified by widget tests, CI `33006998608`
- [ ] Accessibility checks
- [ ] Motion/reduced-motion behavior
- [ ] Touch target and keyboard checks
- [x] Bangla numerals — `toBanglaDigits` converts Latin 0-9 to Bangla ০-৯, `money()` uses Bangla numerals in bn mode (`৳৮৫০`, `৳০`, `৳১৪০০`) and Latin + BDT in en mode (`BDT 850`), verified by `app_text_test.dart` money formatting + `sale_entry_screen_test.dart` Bangla numerals test, CI `33006998608` — **not yet device-validated for numerals (CI-verified only)**
- [x] Language toggle — Settings language section with `RadioGroup` + `RadioListTile` bn/en (script-pure), `onLocaleChanged` callback in `main.dart` rebuilds the active workspace and persists the choice; `settings_screen_test.dart` follows Settings → English → workspace and checks the saved preference (PR #12, CI run `36486253903`, analyze and widget tests passed) — **not yet device-validated for toggle**

## Gate 8 — Validation

- [x] Unit tests — `flutter test` 92/92 PASS at `9e25997`, CI `33006998608` (analyze clean No issues found!, legacy audit success, APK built 163 MB + badging `com.songjog.songjog` `0.1.0` `24/36` `Songjog`)
- [x] Domain tests — `sale_test.dart`, `diagnostic_*_test.dart`, `export_filename_test.dart`, `takaToMinor`/`minorToTaka`/`derivePaymentStatus`/`clampPaid`/`calculateReturnable`/`toBanglaDigits` tests, `app_text_test.dart` money formatting + script purity, CI `33006998608`
- [x] Persistence tests — `sqlite_store_test.dart` via sqflite_common_ffi + `sale_service_test.dart` persistence incl overpayment clamp + failure recording + returnable, CI `33006998608`
- [ ] Integration tests — onboarding widget tests + sale entry widget flows + workspace home widget tests + settings tests exist (onboarding → workspace routing, fast sale entry, workspace home recent list), but full integration smoke (offline recovery, inventory, large history) not yet
- [x] Real-device tests — historical device validation COMPLETE for export/diagnostic milestone at `8e21317`/`8206b8d` (artifacts 104327 + 120529, Redmi Turbo 4 Pro); fast sale entry + workspace home + payment/due + restart persistence + export at `ddce6f7` **device-validated via Record 3 artifacts `184910.json` (Green It, 4 sales: Ssd 250000 paid, hdd qty2 300000 partial, #s 50000 paid, multi-line 1235800 partial) + `184952.json` (23 events, 2 app_start, Redmi 25053RT47C SDK36 bn debug) — 17/22 PASS, overpayment returnable + en BDT pending** — see `PHYSICAL_DEVICE_VALIDATION.md` Record 3; new fixes (returnable UI, Bangla numerals, locale toggle, sale-entry reactivity) **CI GREEN 92/92 at `9e25997` via `33006998608` but NOT yet device-validated**
- [ ] Regression test
- [ ] Release build reproducibility — only debug APK built (`app-debug.apk` 163 MB at `3ebac8b`), no release signing

Only verified gates may be reported as complete. Historical device artifacts must not be reused as proof for new HEAD features (see `PHYSICAL_DEVICE_VALIDATION.md`).
