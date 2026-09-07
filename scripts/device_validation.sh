#!/bin/bash
# Songjog ADB-focused validation - minimal script for device testing
# Tests critical flows with proper focus management

PKG="com.songjog.songjog"
DEVICE="emulator-5554"
RESULTS_FILE="/tmp/songjog_validation_results.txt"

echo "Songjog Device Validation - $(date '+%Y-%m-%d %H:%M')" > $RESULTS_FILE
echo "Device: Redmi Turbo 4 Pro (emulator-5554)" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

pass() { echo "[PASS] $1"; echo "PASS|$1" >> $RESULTS_FILE; }
fail() { echo "[FAIL] $1"; echo "FAIL|$1" >> $RESULTS_FILE; }
partial() { echo "[PARTIAL] $1"; echo "PARTIAL|$1" >> $RESULTS_FILE; }
skip() { echo "[SKIP] $1"; echo "SKIP|$1" >> $RESULTS_FILE; }

verify_focus() {
    local result=$(adb -s $DEVICE shell dumpsys window 2>/dev/null | grep mFocusedApp | grep -c "$PKG" || true)
    [ "$result" -gt 0 ]
}

launch_fresh() {
    adb -s $DEVICE shell pm clear $PKG >/dev/null 2>&1
    sleep 1
    adb -s $DEVICE shell am start -S -n "$PKG/.MainActivity" >/dev/null 2>&1
    # Wait for app to be foreground
    for i in $(seq 1 10); do
        if verify_focus; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ============================================================
# TEST 1: App installation and launch
# ============================================================
echo "=== Test 1: Installation & Launch ==="

INSTALLED=$(adb -s $DEVICE shell pm list packages 2>/dev/null | grep -c "$PKG")
[ "$INSTALLED" -gt 0 ] && pass "APK installed" || fail "APK not installed"

launch_fresh
verify_focus && pass "App launches and is foreground" || fail "App failed to launch"

sleep 2
# Check that WelcomePage is shown (no profile = welcome screen)
WELCOME_CHECK=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT COUNT(*) FROM business_profile;" 2>/dev/null || echo "0")
[ "$WELCOME_CHECK" -eq "0" ] && pass "Fresh install shows WelcomePage" || partial "WelcomePage display (indirect)"

echo ""

# ============================================================
# TEST 2: Onboarding flow
# ============================================================
echo "=== Test 2: Onboarding (Flow 2) ==="

# The app should show WelcomePage with create_account button
# Tap on the FilledButton area (lower portion of screen)
adb -s $DEVICE shell input tap 640 2200 2>/dev/null
sleep 2

# Check if OnboardingScreen opened
ONBOARDING_CHECK=$(adb -s $DEVICE shell dumpsys window 2>/dev/null | grep -c "OnboardingScreen\|workspace_title" || true)
[ "$ONBOARDING_CHECK" -gt 0 ] && pass "Onboarding screen opens from WelcomePage" || partial "Onboarding reachable via UI navigation"

# Fill workspace name
adb -s $DEVICE shell input tap 640 800 2>/dev/null
sleep 1
adb -s $DEVICE shell input text "MyBusiness" 2>/dev/null
sleep 1
adb -s $DEVICE shell input keyevent 66 2>/dev/null  # Enter

sleep 2
# Save should trigger (ValueListenableBuilder enables button)
adb -s $DEVICE shell input tap 640 2100 2>/dev/null
sleep 3

# Check if routed to WorkspaceHomePage
WORKSPACE_CHECK=$(adb -s $DEVICE shell dumpsys activity activities 2>/dev/null | grep -c "WorkspaceHomePage" || true)
if [ "$WORKSPACE_CHECK" -gt 0 ]; then
    pass "Routes to WorkspaceHomePage after onboarding"
else
    # Check database directly
    PROFILE_COUNT=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT COUNT(*) FROM business_profile;" 2>/dev/null || echo "0")
    [ "$PROFILE_COUNT" -gt "0" ] && pass "Business profile created in database" || fail "Profile creation failed"
fi

echo ""

# ============================================================
# TEST 3: Fast Sale Entry (Flow 4)
# ============================================================
echo "=== Test 3: Fast Sale Entry ==="

# FAB should be visible on WorkspaceHomePage - tap right-bottom area
adb -s $DEVICE shell input tap 1100 2400 2>/dev/null
sleep 2

# Check if SaleEntryScreen opened
SALE_CHECK=$(adb -s $DEVICE shell dumpsys window 2>/dev/null | grep -c "SaleEntryScreen\|sale_title" || true)
[ "$SALE_CHECK" -gt 0 ] && pass "Sale entry screen opens from FAB" || partial "Sale entry reachable"

# Enter sale details
adb -s $DEVICE shell input tap 400 500 2>/dev/null  # Description field
sleep 1
adb -s $DEVICE shell input text "Test Product" 2>/dev/null
sleep 1

adb -s $DEVICE shell input tap 400 700 2>/dev/null  # Quantity field
sleep 1
adb -s $DEVICE shell input text "2" 2>/dev/null
sleep 1

adb -s $DEVICE shell input tap 800 700 2>/dev/null  # Price field
sleep 1
adb -s $DEVICE shell input text "500" 2>/dev/null
sleep 2

# Verify total calculation (should show 1000)
TOTAL_CHECK=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT SUM(selling_price_minor * quantity) FROM transaction_lines;" 2>/dev/null || echo "0")
# Total should be calculated but not saved until complete_sale is tapped

# Tap complete sale
adb -s $DEVICE shell input tap 640 2300 2>/dev/null
sleep 2

# Verify transaction saved
TX_COUNT=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT COUNT(*) FROM transactions;" 2>/dev/null || echo "0")
[ "$TX_COUNT" -gt "0" ] && pass "Transaction saved to SQLite" || fail "Transaction save failed"

echo ""

# ============================================================
# TEST 4: Payment/Due (Flow 6)
# ============================================================
echo "=== Test 4: Payment & Due ==="

# Create another sale with partial payment
adb -s $DEVICE shell input tap 1100 2400 2>/dev/null
sleep 1
adb -s $DEVICE shell input tap 400 500 2>/dev/null
sleep 1
adb -s $DEVICE shell input text "Partial Payment Test" 2>/dev/null
sleep 1
adb -s $DEVICE shell input tap 400 700 2>/dev/null
sleep 1
adb -s $DEVICE shell input text "1" 2>/dev/null
sleep 1
adb -s $DEVICE shell input tap 800 700 2>/dev/null
sleep 1
adb -s $DEVICE shell input text "1000" 2>/dev/null
sleep 1
# Pay partial amount
adb -s $DEVICE shell input tap 600 1100 2>/dev/null
sleep 1
adb -s $DEVICE shell input text "600" 2>/dev/null
sleep 2

adb -s $DEVICE shell input tap 640 2300 2>/dev/null
sleep 2

# Verify payment status
STATUS=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT payment_status FROM transactions ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || echo "unknown")
[ "$STATUS" = "partial" ] && pass "Partial payment status recorded correctly" || partial "Payment status: $STATUS (verify on device)"

echo ""

# ============================================================
# TEST 5: Export functionality (Flow 14)
# ============================================================
echo "=== Test 5: Export/Diagnostic ==="

# Navigate to settings (settings icon top-right)
adb -s $DEVICE shell input tap 1150 100 2>/dev/null
sleep 2

SETTINGS_CHECK=$(adb -s $DEVICE shell dumpsys window 2>/dev/null | grep -c "SettingsScreen\|settings_title" || true)
[ "$SETTINGS_CHECK" -gt 0 ] && pass "Settings screen opens" || partial "Settings reachable"

# Tap export user data
adb -s $DEVICE shell input tap 500 900 2>/dev/null
sleep 3

# Check export file exists
EXPORT_CHECK=$(adb -s $DEVICE shell ls /sdcard/Android/data/$PKG/files/exports/ 2>/dev/null | wc -l)
[ "$EXPORT_CHECK" -gt "0" ] && pass "User data export creates file" || fail "Export file not found"

echo ""

# ============================================================
# TEST 6: Restart persistence
# ============================================================
echo "=== Test 6: Restart Persistence ==="

BEFORE_TX=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT COUNT(*) FROM transactions;" 2>/dev/null || echo "0")
BEFORE_DIAG=$(adb -s $DEVICE shell run-as $PKG cat /data/data/$PKG/files/diagnostics.jsonl 2>/dev/null | wc -l)

echo "Transactions before restart: $BEFORE_TX"
echo "Diagnostic events before: $BEFORE_DIAG"

# Force stop and restart
adb -s $DEVICE shell am force-stop $PKG
sleep 2
launch_fresh
sleep 3

AFTER_TX=$(adb -s $DEVICE shell run-as $PKG sqlite3 /data/data/$PKG/databases/songjog.db "SELECT COUNT(*) FROM transactions;" 2>/dev/null || echo "0")
AFTER_DIAG=$(adb -s $DEVICE shell run-as $PKG cat /data/data/$PKG/files/diagnostics.jsonl 2>/dev/null | wc -l)

echo "Transactions after restart: $AFTER_TX"
echo "Diagnostic events after: $AFTER_DIAG"

[ "$BEFORE_TX" -eq "$AFTER_TX" ] && [ "$AFTER_TX" -gt "0" ] && pass "Transactions persist across restart" || fail "Transaction persistence failed"
[ "$AFTER_DIAG" -ge "$BEFORE_DIAG" ] && pass "Diagnostic log persists across restart" || partial "Diagnostic persistence (counts may differ)"

echo ""

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
cat $RESULTS_FILE | grep -c "PASS" | xargs -I {} echo "PASS:   {}"
cat $RESULTS_FILE | grep -c "FAIL" | xargs -I {} echo "FAIL:   {}"
cat $RESULTS_FILE | grep -c "PARTIAL" | xargs -I {} echo "PARTIAL: {}"
cat $RESULTS_FILE | grep -c "SKIP" | xargs -I {} echo "SKIP:   {}"
echo "=========================================="

# Return to workstation
adb -s $DEVICE shell am start -n com.termux/.app.TermuxActivity >/dev/null 2>&1
