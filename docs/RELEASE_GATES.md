# Release Gates

A feature is not release-ready because its documentation exists. It must pass the applicable implementation, test and product gates.

**Current whole-flow status:** see `MVP_ACCEPTANCE.md` (2026-09-29 source audit: 0/14 complete, 8 partial, 6 without a usable path). A checked component below proves only the narrow behavior described on that line. It does not complete its parent gate or a P0 release flow. CI passing and a debug APK do not qualify physical-device behavior or commercial release.

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

- [ ] Product/service creation — product entry UI and repository storage exist, but the complete flow lacks a widget/device test; distinct service setup is absent.
- [ ] Fast sale acceptance flow — manual line entry, exact minor-unit money parsing, payment/due calculation and local save are implemented and tested (`sale_service_test.dart`, `sale_entry_screen_test.dart`); Record 3 at `ddce6f7` provides historical device evidence for the manual-entry subset. The required selection of a saved product/service is not implemented. Returnable, Bangla numerals and locale behavior added after that device round are not qualified by Record 3.
- [x] Multi-line transaction — `SaleEntryService.saveSale` accepts `List<({description, quantity, priceMinor})>`, total = sum `lineTotalMinor`, verified by `sale_service_test.dart` multi-line totals (180000) + `sale_entry_screen_test.dart` multi-line widget test, CI `33006998608` (92/92), **device-validated at `ddce6f7` via multi-line sale lines=2 total=1235800 (282800+953000) in diagnostic `184952.json` + user-data `184910.json`**
- [x] Payment / partial payment / due + Returnable — `derivePaymentStatus` (unpaid/partial/paid, zero total never paid), `clampPaid` [0,total] prevents silent overpayment, `calculateReturnable` = entered - total when overpaid, due = total - clampedPaid, returnable UI (`returnable` + `change_due` keys, ৳ + Bangla numerals in bn), optional `PaymentMethod`, UI shows paid/partial/unpaid + due + returnable when >0, verified by `sale_service_test.dart` (clamp + returnable) + `sale_entry_screen_test.dart` (partial, paid, overpayment clamped + returnable UI), CI `33006998608` (92/92), **device-validated at `ddce6f7`: partial (300000/250000) + paid (250000/250000, 50000/50000) + due derivable + payment_method cash in `184910.json` + `184952.json`; overpayment returnable NOT yet device-validated (CI-verified only)**
- [ ] Private actual cost and profit — optional cost can be entered on a product, but sale entry uses `costMinor: null` and does not link that product; the required posted cost basis and profit path is incomplete.
- [ ] Customer/service recipient — customer records and detail screen exist, but sale entry does not attach a customer and the service-recipient flow is absent.
- [ ] Purchase/expense — entry screens are reachable, but the complete save-and-summary path lacks widget/device evidence.
- [ ] Return/refund/adjustment

## Gate 4 — Documents

- [ ] Receipt generation — a text share sheet exists, but `TransactionDetailsPage` passes it an empty `TransactionRecord`; the preview is not a valid receipt for the selected sale.
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
- [ ] Complete localization — `app_text_test.dart` checks key parity inside `AppText`, but it does not cover all literal UI text; `ProductListScreen` and `ShareReceiptSheet` contain Portuguese labels outside `AppText`.
- [ ] Loading/empty/error/offline states — some loading, empty and error states are present; no complete offline-state or recovery-path validation is recorded.
- [ ] Accessibility checks
- [ ] Motion/reduced-motion behavior
- [ ] Touch target and keyboard checks
- [x] Bangla numerals — `toBanglaDigits` converts Latin 0-9 to Bangla ০-৯, `money()` uses Bangla numerals in bn mode (`৳৮৫০`, `৳০`, `৳১৪০০`) and Latin + BDT in en mode (`BDT 850`), verified by `app_text_test.dart` money formatting + `sale_entry_screen_test.dart` Bangla numerals test, CI `33006998608` — **not yet device-validated for numerals (CI-verified only)**
- [ ] Language toggle — Settings offers Bangla and English and persists a selection, but current `main.dart` changes `_locale` without rebuilding the app root; the existing main-branch test checks option visibility only. Immediate workspace-language change and physical-device behavior remain unverified.

## Gate 8 — Validation

- [x] Unit tests — `flutter test` 92/92 PASS at `9e25997`, CI `33006998608` (analyze clean No issues found!, legacy audit success, APK built 163 MB + badging `com.songjog.songjog` `0.1.0` `24/36` `Songjog`)
- [x] Domain tests — `sale_test.dart`, `diagnostic_*_test.dart`, `export_filename_test.dart`, `takaToMinor`/`minorToTaka`/`derivePaymentStatus`/`clampPaid`/`calculateReturnable`/`toBanglaDigits` tests, `app_text_test.dart` money formatting + script purity, CI `33006998608`
- [x] Persistence tests — `sqlite_store_test.dart` via sqflite_common_ffi + `sale_service_test.dart` persistence incl overpayment clamp + failure recording + returnable, CI `33006998608`
- [ ] Integration tests — onboarding widget tests + sale entry widget flows + workspace home widget tests + settings tests exist (onboarding → workspace routing, fast sale entry, workspace home recent list), but full integration smoke (offline recovery, inventory, large history) not yet
- [ ] Current release-flow device validation — export/diagnostic and manual fast-sale subsets have historical Redmi Turbo 4 Pro evidence (`PHYSICAL_DEVICE_VALIDATION.md`, including Record 3 at `ddce6f7`). That evidence does not qualify the current head's newer screens or the 14 complete P0 flows. Record 3 passed 17 of 22 checks; returnable and English display were pending.
- [ ] Regression test
- [ ] Release build reproducibility — only debug APK built (`app-debug.apk` 163 MB at `3ebac8b`), no release signing

Only verified gates may be reported as complete. Historical device artifacts must not be reused as proof for new HEAD features (see `PHYSICAL_DEVICE_VALIDATION.md`).
