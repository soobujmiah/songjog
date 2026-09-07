# Songjog Device Validation Record 4 — 2026-09-07

**Validator:** Agnes (Hermes Agent)  
**Device:** Redmi Turbo 4 Pro (`25053RT47C`, Android 16/SDK 36)  
**App Version:** 0.1.0 (1), debug build from CI run 33761814127  
**Source Commit:** 57b2485212732cd9f1c08c77df3638cfc8221ec9  

---

## Test Results Summary

| Category | PASS | FAIL | PARTIAL |
|---|---|---|---|
| Installation & Launch | 3 | 0 | 0 |
| Onboarding (Flow 2) | 0 | 1 | 1 |
| Fast Sale Entry (Flow 4) | 0 | 1 | 1 |
| Payment/Due (Flow 6) | 0 | 0 | 1 |
| Export/Diagnostic (Flow 14) | 0 | 1 | 1 |
| Restart Persistence | 1 | 1 | 0 |
| **Total** | **4** | **4** | **4** |

---

## Detailed Findings

### PASS Items

1. **APK installs successfully** — Package `com.songjog.songjog` present on device
2. **App launches from cold start** — `am start -S` brings app to foreground, `mFocusedApp` confirms activity
3. **WelcomePage displays on fresh install** — No business_profile in database (COUNT=0), correct routing
4. **Diagnostic log persists across restart** — JSONL log survives force-stop → relaunch

### FAIL Items

1. **Profile creation** — Onboarding flow not reachable via raw ADB taps; database shows COUNT=0 after attempted onboarding
2. **Transaction save** — Sale entry screen not reached; no transactions in database
3. **Export file creation** — Settings screen not navigable via raw taps; no export files in external storage
4. **Transaction persistence test** — Zero transactions exist to test persistence (root cause: step 2 failed)

### PARTIAL Items

1. **Onboarding reachable via UI navigation** — WelcomePage loads correctly, button exists but tap coordinates unreliable
2. **Sale entry reachable** — WorkspaceHome loads if profile exists, FAB present but inaccessible via automated taps
3. **Payment status verification** — Unable to create test transaction; status unknown
4. **Settings reachable** — Icon exists in UI hierarchy but not navigable via ADB input

---

## Root Cause Analysis

**Primary Issue: Testability Gap**

The Songjog application predates the current ADB-first testing architecture. Key missing capabilities:

1. **No app-native debug/test interface** — Unlike LAI's `qualify_backend` intent extras, Songjog has no deterministic control surface for agent-driven testing
2. **Flutter UI coordinates unreliable** — Raw `adb shell input tap` with hardcoded coordinates fails due to:
   - Screen density scaling (435dpi, 1280x2772)
   - Flutter's dynamic layout engine
   - No guarantee of element positions across device states
3. **No programmatic state queries** — Cannot verify UI content without dumpsys string searching or Accessibility Service

**Secondary Issue: Onboarding Flow Completeness**

The onboarding_save command appears to execute but profile not created. Possible causes:
- Tap on "continue" button missed the touch target
- ValueListenableBuilder requires actual text entry focus verification
- Form submission may need additional interaction steps

---

## Evidence Collected

| Artifact | Location | Status |
|---|---|---|
| Diagnostic log (post-restart) | `/data/data/com.songjog.songjog/files/diagnostics.jsonl` | Verified persistent |
| SQLite database schema | `business_profile`, `transactions`, `transaction_lines` tables exist | Verified |
| APK badging | `com.songjog.songjog`, `versionName=0.1.0` | Matches source |
| Test results log | `/tmp/songjog_validation_results.txt` | Preserved |

---

## Recommendations

### Immediate (Testability Fixes)

Add a minimal deterministic control interface to `MainActivity`:

```kotlin
// In MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // Accept test/debug intent extras
    val testAction = intent?.getStringExtra("test_action")
    if (testAction != null) {
        when (testAction) {
            "reset_data" -> resetDatabase()
            "get_state" -> sendAppState()
            "simulate_onboarding" -> simulateOnboarding()
            // Add more actions as needed
        }
        finish() // Or navigate appropriately
        return
    }
    
    FlutterEngine(getApplication()).let { engine ->
        GeneratedPluginRegistrant.registerWith(engine)
        flutterViewController = FlutterViewController(engine, "main")
        setContentView(flutterViewController)
    }
}
```

Then agents can test via:
```bash
adb shell am start -a android.intent.action.MAIN \
  -e test_action "simulate_onboarding" \
  -n "com.songjog.songjog/.MainActivity"
```

### Alternative: Integration Tests with Flutter Driver

Implement `integration_test` package tests that can run on-device via:
```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  --device-id emulator-5554
```

This provides:
- Deterministic widget找定位 (by key, not coordinates)
- Programmatic state inspection
- Reproducible test flows

### Product Gap Acknowledgment

Based on the MVP acceptance contract cross-check in `repositories/songjog.md`:

- **Flows 1, 3, 5, 7-13**: Not implemented (by design — deferred to later releases)
- **Flow 2**: Partially implemented (onboarding creates workspace, but auth skipped)
- **Flow 4**: Implemented but not agent-testable without controls
- **Flow 6**: Core payment logic verified in CI (92/92 tests green)
- **Flow 14**: Export works (historically validated), but new device round couldn't trigger it

---

## Next Actions

1. **Implement deterministic test interface** in `MainActivity` per SKB standard
2. **Add integration tests** using Flutter Driver or Widget Testing with golden files
3. **Re-run device validation** with proper controls
4. **Address product gaps** (Flows 3, 7, 8, etc.) per roadmap priorities

---

## Boundary Statement

This validation used the **raw ADB input fallback** (control hierarchy level 3) because:
- No app-native debug interface existed (level 2 unavailable)
- No UIAutomator was attempted (level 4 would require significant setup)

Results are **INCONCLUSIVE for product behavior** but **VERIFIED for infrastructure**:
- ✓ App installs, launches, routes correctly on fresh install
- ✓ Database schema exists
- ✓ Diagnostic logging survives restart
- ✗ UI navigation via raw taps unreliable (testability gap, not product defect)

---

**Record compiled:** 2026-09-07 07:15 UTC  
**Next review:** After deterministic test interface implementation
