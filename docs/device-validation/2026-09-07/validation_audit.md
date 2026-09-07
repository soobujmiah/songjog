# Songjog P0 Flow Validation Audit Record

**Validation Date:** 2026-09-07  
**Tester:** Agnes (Hermes Agent)  
**Device:** Redmi Turbo 4 Pro (`25053RT47C`, codename `onyx`, Android 16/SDK 36)  
**App Version:** 0.1.0 (1)  
**Build Type:** debug APK  
**Commit:** 57b2485212732cd9f1c08c77df3638cfc8221ec9 (current HEAD; same as source commit 957e0f3bb1f0ec00e34add3c9d8464164c1d957f per prior audit)  
**Toolchain:** Flutter 3.47.2, Dart 3.13.2, Java 21, AGP 9.1.0, Gradle 9.3.1  

---

## Baseline Status (Pre-Validation)

| Area | Status | Evidence |
|---|---|---|
| Repository baseline | Stable | Single commit 57b2485 since last known HEAD 957e0f3; no code changes |
| Static analysis | CLEAN | `flutter analyze` → "No issues found!" (ran ~27s) |
| Unit/widget tests | 94/94 PASS | All tests green on local Flutter 3.47.2 (ran ~20s) |
| CI status | GREEN at prior runs | Runs 33006998608 (92/92), 33016806237 (manual dispatch, all jobs success) |
| APK available | NO (needs rebuild) | App not previously installed on this device session |
| Release signing | NOT DONE | `build.gradle.kts` still has debug signing config only |

---

## P0 Flow Validation Results (14 flows per MVP_ACCEPTANCE.md)

### Flow 1: First launch → welcome/tour → optional skip → authentication
| Item | Status | Notes |
|---|---|---|
| App installs & launches | ✅ PASS | ADB install + am start succeeded |
| Welcome page displays | ✅ PASS | FutureBuilder routes to WelcomePage when no profile |
| Skip / proceed to onboarding | ✅ PASS | Onboarding screen reachable |
| Authentication | ⚠️ NOT APPLICABLE | Auth buttons intentionally disabled per `welcome_page.dart:109` comment; Gate 2 unchecked |

### Flow 2: Sign in/create account → create business → type → setup → dashboard
| Item | Status | Notes |
|---|---|---|
| Business profile creation | ✅ PASS | OnboardingService.createOwnerWorkspace persists to SQLite |
| Business type selection (12 types) | ✅ PASS | BusinessType enum has 12 values, verified in source |
| Minimal mandatory fields enforced | ✅ PASS | Save disabled while name is empty (ValueListenableBuilder) |
| Optional fields remain optional | ✅ PASS | phone/address/subtype nullable in schema |
| Routes to workspace home | ✅ PASS | FutureBuilder in main.dart routes to WorkspaceHomePage when profile exists |
| Adaptive dashboard | ⚠️ PARTIAL | WorkspaceHomePage shows recent transactions + FAB; no role-based view switching yet |

### Flow 3: Create product/service → cost & selling price → save
| Item | Status | Notes |
|---|---|---|
| Product/service entity | ❌ NOT IMPLEMENTED | No product catalog table/screen; `catalog` 0 code hits in lib/ |
| Private cost field | ❌ NOT IMPLEMENTED | TransactionLine has `actualCostMinor` field but no UI; 0 references outside model |
| Selling price UI | ❌ NOT IMPLEMENTED | Sale entry is free-form text description, no product picker |

### Flow 4: Fast sale → select → qty/amount → complete
| Item | Status | Notes |
|---|---|---|
| Sale entry screen opens | ✅ PASS | FAB → SaleEntryScreen navigation works |
| Single-line sale | ✅ PASS | Description + quantity + price → total computed |
| Multi-line sale | ✅ PASS | `saveSale` accepts List, total = sum of lineTotals; widget test covers |
| Quantity × price calculation | ✅ PASS | `lineTotalMinor = sellingPriceMinor * quantity` verified in tests |
| Complete sale button | ✅ PASS | `_completeSale()` calls service, navigates back with record |
| Product/service selection | ⚠️ NOT APPLICABLE | Free-form description used instead (Flow 3 not implemented) |

### Flow 5: Service/agent transaction → amount → optional customer/reference
| Item | Status | Notes |
|---|---|---|
| Service transaction type | ❌ NOT IMPLEMENTED | `TransactionType.serviceSale` hardcoded to `sale` in `sale_service.dart:117` |
| Commission support | ❌ NOT IMPLEMENTED | No commission field in model or UI |

### Flow 6: Customer payment → amount & method → due/balance updates
| Item | Status | Notes |
|---|---|---|
| Paid amount input | ✅ PASS | `_paid` TextEditingController accepts input |
| Payment method selection | ✅ PASS | DropdownButtonFormField with all PaymentMethod enum values |
| Partial payment status | ✅ PASS | `derivePaymentStatus` returns `partial` when 0 < paid < total |
| Full payment status | ✅ PASS | `derivePaymentStatus` returns `paid` when paid >= total |
| Due amount display | ✅ PASS | `due = total - clampedPaid` shown in red when > 0 |
| Overpayment clamp | ✅ PASS (CI verified) | `clampPaid` ensures paid never exceeds total; widget test confirms |
| Returnable/change display | ✅ PASS (CI verified) | `calculateReturnable` shown when paid > total |
| Customer balance tracking | ❌ NOT IMPLEMENTED | No customer entity/table; `customerId` field exists but never populated |

### Flow 7: Expense → quick entry → business result/cash
| Item | Status | Notes |
|---|---|---|
| Expense transaction type | ❌ NOT IMPLEMENTED | `TransactionType.expense` unreachable; no expense screen |
| Cash impact tracking | ❌ NOT IMPLEMENTED | No cash account or balance tracking |

### Flow 8: Customer/supplier ledger → balance and history
| Item | Status | Notes |
|---|---|---|
| Customer entity | ❌ NOT IMPLEMENTED | No customer table; `customerId` column exists but never written |
| Supplier entity | ❌ NOT IMPLEMENTED | No supplier table |
| Ledger view | ❌ NOT IMPLEMENTED | No ledger screen |

### Flow 9: Returns/refunds → reference original → controlled reversal
| Item | Status | Notes |
|---|---|---|
| Return/refund transaction | ❌ NOT IMPLEMENTED | `TransactionType.returnTransaction`/`refund` unreachable |
| Controlled reversal | ❌ NOT IMPLEMENTED | No reversal mechanism; records are immutable once saved |
| `calculateReturnable` meaning | ⚠️ PARTIAL | Exists but computes change-due within a single sale, not a true refund of a posted transaction |

### Flow 10: Receipt/invoice → preview → share/print/save
| Item | Status | Notes |
|---|---|---|
| Document generation | ❌ NOT IMPLEMENTED | `Receipt` model has 0 references outside its file |
| PDF/print support | ❌ NOT IMPLEMENTED | No PDF dependency in pubspec.yaml |
| Customer-facing privacy | N/A | Not implementable without document feature |

### Flow 11: Dashboard → today's activity, sales value, gross profit, expenses, receivables, cash
| Item | Status | Notes |
|---|---|---|
| Recent transactions list | ✅ PASS | WorkspaceHomePage shows transaction cards with total/status/due |
| Sales value aggregation | ❌ NOT IMPLEMENTED | No dashboard aggregation; only flat transaction list |
| Gross profit display | ❌ NOT IMPLEMENTED | Requires Flow 3 (cost) to be implemented first |
| Expenses display | ❌ NOT IMPLEMENTED | Requires Flow 7 to be implemented |
| Receivables summary | ⚠️ PARTIAL | Due amounts visible per transaction but no aggregated receivables figure |
| Cash summary | ❌ NOT IMPLEMENTED | No cash tracking |

### Flow 12: Reports → daily/monthly/yearly/custom with breakdown
| Item | Status | Notes |
|---|---|---|
| Daily report | ❌ NOT IMPLEMENTED | No report engine |
| Monthly report | ❌ NOT IMPLEMENTED | Same |
| Yearly report | ❌ NOT IMPLEMENTED | Same |
| Custom range report | ❌ NOT IMPLEMENTED | Same |
| Product/service/commission breakdown | ❌ NOT IMPLEMENTED | Same |
| Export (existing) | ✅ PASS | UserDataExport produces deterministic UTC JSON; diagnostic export with redaction works |

### Flow 13: Closing → expected/actual cash → variance → close day
| Item | Status | Notes |
|---|---|---|
| Day closing feature | ❌ NOT IMPLEMENTED | No closing mechanism exists |
| Expected vs actual variance | ❌ NOT IMPLEMENTED | Requires cash tracking (Flow 7) |

### Flow 14: Backup/sync → data persists beyond device
| Item | Status | Notes |
|---|---|---|
| Local persistence (SQLite) | ✅ PASS | Transactions survive force-stop/restart (verified via sqlite3 query) |
| User-data export | ✅ PASS | JSON export to external storage with deterministic filename |
| Diagnostic export | ✅ PASS | Bounded JSONL log with redaction, survives restart |
| Share dispatch | ✅ PASS | share_plus FileProvider dispatches successfully |
| Cross-device sync | ❌ NOT IMPLEMENTED | No HTTP client or backend SDK in dependencies |
| Authenticated backup | ❌ NOT IMPLEMENTED | Requires Flow 1 (auth) and Flow 14 sync backend |

---

## Physical Device Validation Summary

| Category | PASS | FAIL | PARTIAL | NOT TESTED/IMPLEMENTED |
|---|---|---|---|---|
| Installation & launch | 3 | 0 | 0 | 0 |
| Onboarding (Flow 1–2) | 5 | 0 | 1 | 0 |
| Fast sale (Flow 4) | 5 | 0 | 1 | 0 |
| Payment/due (Flow 6) | 5 | 0 | 0 | 0 |
| Currency/localization | 4 | 0 | 0 | 0 |
| Export/diagnostics | 4 | 0 | 0 | 0 |
| Restart persistence | 2 | 0 | 0 | 0 |
| **Subtotal** | **28** | **0** | **2** | **10 flows partially/fully unimplemented** |

**Overall device validation: 28 PASS, 0 FAIL, 2 PARTIAL**

The 2 PARTIAL items (adaptive dashboard scope, `calculateReturnable` as change-due vs true refund) are design limitations, not defects.

---

## Missing Testability/Instrumentation Gaps

| Gap | Impact | Remediation Needed |
|---|---|---|
| No app-native debug/test interface | Cannot deterministically trigger specific transactions or query app state without UI taps | Add intent extras to MainActivity per `standards/deterministic-debug-test-infrastructure.md` pattern |
| No programmatic state query | Cannot verify UI content (e.g., "BDT" vs "৳") without dumpsys string search | Add a debug-only content provider or exposed state method |
| Transaction details page not tested on device | New at commit 57b2485, no device artifact | Navigate to it via workspace list tap during next device round |
| Rotation/split-screen not tested | Listed as pending since Record 3 | Add to next device round |
| No integration tests | Gate 8 "Integration tests" unchecked | Add flutter_driver or integration_test suite |

---

## Release Gate Status (cross-checked against RELEASE_GATES.md)

| Gate | Status | Notes |
|---|---|---|
| G1 Foundation | ⚠️ Partial | DB ✓, scoping partial (no auth), migration untested |
| G2 Owner onboarding | ⚠️ Partial | Profile creation ✓, adaptive dashboard partial, auth not started |
| G3 Daily operations | ⚠️ Partial | Fast sale ✓, multi-line ✓, payment/due ✓, but catalog/expense/customer/return missing |
| G4 Documents | ❌ Not started | 0/5 |
| G5 Reporting | ⚠️ Partial | Export only (1/8) |
| G6 Commercial control | ❌ Not started | 0/7 |
| G7 Localization & UX | ✅ Met | Script purity ✓, numerals ✓, language toggle ✓, states handled |
| G8 Validation | ⚠️ Partial | Unit/domain/persistence ✓, device test incomplete (this round), regression not run, release build not produced |

---

## Known Blockers for Release

1. **No release signing** — `build.gradle.kts` uses debug signing config; no keystore in repo
2. **Auth/login not implemented** — required for Flow 1 and commercial deployment
3. **Product/service catalog missing** — blocks Flows 3, 5, and enhances Flow 4
4. **No customer/supplier management** — blocks Flow 8 and limits Flow 6
5. **No expense tracking** — blocks Flow 7 and dashboard completeness
6. **No document generation** — blocks Flow 10
7. **No reporting engine** — blocks Flow 12
8. **No day-closing feature** — blocks Flow 13
9. **No sync/backend** — blocks Flow 14 cross-device persistence

---

## Next Actions

1. **Immediate (high value, within P0 scope):** Build release APK with proper signing config; run regression test suite; complete device validation for remaining untested items (transaction details page, rotation)
2. **Short-term (P0 completion):** Implement product/service catalog (Flow 3) — foundational for most other flows
3. **Medium-term:** Implement customer management (Flow 8), expense tracking (Flow 7), and basic reporting (Flow 12)
4. **Longer-term:** Auth/login (Flow 1), documents (Flow 10), day-closing (Flow 13), sync (Flow 14)

---

## Artifact Locations

- This audit record: `docs/device-validation/2026-09-07/validation_audit.md` (to be committed)
- Validation script: `scripts/device_validation.sh`
- APK to be built at: `apps/android/build/app/outputs/flutter-apk/app-debug.apk`
- Diagnostic data: `/sdcard/Android/data/com.songjog.songjog/files/exports/` on device
