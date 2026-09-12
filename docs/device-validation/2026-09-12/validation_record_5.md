# Device Validation Record 5 — 2026-09-12

**HEAD:** `a490f28df3a9b4b8488f9a2332a01b0b50ada62a`
**CI Run:** [#34612168071](https://github.com/soobujmiah/songjog/actions/runs/34612168071) — Analyze + unit/widget tests ✅ (58s), Legacy audit ✅ (6s), Build debug APK ✅ (4m38s)
**Agent:** Hermes agent on Redmi Turbo 4 Pro (`25053RT47C`, Android 16, SDK 36, Bangla locale)
**Date:** 2026-09-12

## Summary

DebugChannel testability gap resolved (Record 4 recommendation implemented). Native side verified via ADB intent extras; Flutter-side integration pending Flutter installation.

## Test Results

| Operation | Status | Evidence |
|---|---|---|
| App installed & FLAG_DEBUGGABLE | ✅ PASS | `pm dump` shows `flags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]` |
| seed_profile via intent extra | ✅ PASS | `debug_actions.log`: `seed_profile` at 20:51:38Z |
| seed_sale via intent extra | ✅ PASS | `debug_actions.log`: `seed_sale` at 20:52:10Z |
| query_state via intent extra | ✅ PASS | `debug_actions.log`: `query_state` at 20:53:00Z |
| App launches with existing profile | ✅ PASS | `mFocusedApp` = `com.songjog.songjog/.MainActivity` |
| Database schema present | ✅ PASS | `business_profile`, `transactions`, `transaction_lines` tables verified |
| Full DebugChannel Flutter integration | ⏳ PENDING | Requires Flutter installed; CI covers unit/widget tests |

## Pending Device Items

The following items remain **UNKNOWN on device** — require full DebugChannel Flutter-side integration:

- Returnable money UI (overpayment → ফেরত)
- Bangla numerals display on physical screen
- English locale toggle + BDT display
- Sale-entry reactivity (CI-verified at `957e0f3`)
- Transaction details view

## Security Finding (P2)

Hardcoded fallback path `/home/sbj/android-sdk/platform-tools/sqlite3` in `MainActivity._sqliteBin()` will fail on any device except the build machine. Should use bundled binary or skip subprocess entirely. Does not crash the app — just returns error from sqlite operations.

## Recommendation

Build debug APK from HEAD a490f28 via CI, install on device, test DebugChannel Flutter API via `flutter drive --target=integration_test/debug_channel_integration_test.dart`. Commit new artifacts under `docs/device-validation/2026-09-12/`.
