package com.songjog.songjog

import android.content.pm.PackageManager
import android.os.Bundle
import android.database.sqlite.SQLiteDatabase
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    // ----------------------------------------------------------------
    // DB path helper — sqflite stores the DB at <package>/databases/
    // ----------------------------------------------------------------
    private fun _dbPath(): String = getDatabasePath("songjog.db").absolutePath

    // ----------------------------------------------------------------
    // Channels & intent keys
    // ----------------------------------------------------------------
    private companion object {
        const val CHANNEL = "com.songjog/debug"
        const val EXTRA_ACTION = "test_action"
    }

    // ----------------------------------------------------------------
    // Lifecycle — read intent extras before Flutter starts
    // ----------------------------------------------------------------
    override fun onCreate(savedInstanceState: Bundle?) {
        val action = intent?.getStringExtra(EXTRA_ACTION)
        if (!action.isNullOrEmpty()) {
            _recordAction(action)
            if (action == "seed_profile") {
                _nativeSeedProfile(intent)
            } else if (action == "seed_sale") {
                _nativeSeedSale(intent)
            }
        }
        super.onCreate(savedInstanceState)
    }

    // ----------------------------------------------------------------
    // Plugin registration + debug channel wiring
    // ----------------------------------------------------------------
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryApp" -> _handleQuery(call, result)
                "queryState" -> _handleQueryState(result)
                "resetApp" -> _handleReset(result)
                "seedProfile" -> _handleSeedProfile(call, result)
                "seedSale" -> _handleSeedSale(call, result)
                else -> result.notImplemented()
            }
        }
    }

    // ----------------------------------------------------------------
    // queryApp  — read-only capability probe
    // ----------------------------------------------------------------
    private fun _handleQuery(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key == null) {
            result.error("MISSING_KEY", "required argument 'key' is null", null)
            return
        }
        when (key) {
            "isDebuggable" -> {
                val flags = packageManager.getApplicationInfo(packageName, 0).flags
                result.success((flags and 0x00000002) != 0)
            }
            "packageName" -> result.success(packageName)
            else -> result.error("UNKNOWN_KEY", "no data for key '$key'", null)
        }
    }

    // ----------------------------------------------------------------
    // queryState  — deterministic app-state snapshot (read-only)
    // ----------------------------------------------------------------
    @Suppress("UNCHECKED_CAST")
    private fun _handleQueryState(result: MethodChannel.Result) {
        try {
            val profiles = _sqlCount("SELECT COUNT(*) FROM business_profile")
            val transactions = _sqlCount("SELECT COUNT(*) FROM transactions")
            val lastTotal = _sqlLongOrNull(
                "SELECT COALESCE(MAX(selling_price_minor * quantity), 0) " +
                "FROM transaction_lines WHERE transaction_id IN (" +
                "  SELECT id FROM transactions ORDER BY created_at DESC LIMIT 1" +
                ")"
            )
            result.success(mapOf(
                "profileCount" to profiles,
                "transactionCount" to transactions,
                "lastTransactionTotalMinor" to (lastTotal ?: 0),
            ))
        } catch (e: Exception) {
            result.error("QUERY_STATE_FAIL", e.message, null)
        }
    }

    // ----------------------------------------------------------------
    // resetApp  — atomic sandbox wipe; caller must relaunch the app
    // ----------------------------------------------------------------
    private fun _handleReset(result: MethodChannel.Result) {
        try {
            val db = File(_dbPath())
            val diag = filesDir.resolve("diagnostics.jsonl")
            val exports = filesDir.resolve("exports")
            db.deleteRecursively()
            if (diag.exists()) diag.delete()
            if (exports.exists()) exports.deleteRecursively()
            _recordAction("reset_app")
            result.success(true)
        } catch (e: Exception) {
            result.error("RESET_FAIL", e.message, null)
        }
    }

    // ----------------------------------------------------------------
    // seedProfile  — idempotent workspace creation (deterministic ID)
    // ----------------------------------------------------------------
    @Suppress("UNCHECKED_CAST")
    private fun _handleSeedProfile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val name = (call.argument<Any>("name") as? String)?.trim()
                ?: throw IllegalArgumentException("name is required")
            val bizType = (call.argument<String>("businessType"))
                ?: "retail"
            // Remove any existing profile first (idempotent).
            _sqlExec("DELETE FROM business_profile")
            val id = "adb-seeded-${System.currentTimeMillis()}"
            _sqlExec(
                "INSERT INTO business_profile (id, name, workspace_kind, business_type, subtype, phone, address) VALUES (?, ?, ?, ?, NULL, NULL, NULL)",
                listOf(id, name, "business", bizType)
            )
            _recordAction("seed_profile")
            result.success(mapOf("profileId" to id, "name" to name))
        } catch (e: Exception) {
            result.error("SEED_PROFILE_FAIL", e.message, null)
        }
    }

    // ----------------------------------------------------------------
    // seedSale  — idempotent single-sale insertion (deterministic fields)
    // ----------------------------------------------------------------
    @Suppress("UNCHECKED_CAST")
    private fun _handleSeedSale(call: MethodCall, result: MethodChannel.Result) {
        try {
            val description = (call.argument<String>("description")) ?: "Test Product"
            val quantity = (call.argument<Number>("quantity")?.toDouble()) ?: 1.0
            val priceMinor = (call.argument<Number>("priceMinor")?.toInt()) ?: 50000
            val paidMinor = (call.argument<Number>("paidMinor")?.toInt()) ?: priceMinor
            val paymentMethod = call.argument<String?>("paymentMethod")
            val nowMs = System.currentTimeMillis()
            val txId = "adb-sold-${nowMs}"
            val lineId = "$txId-l0"
            // Compute payment status deterministically.
            val status = when {
                priceMinor <= 0 -> "unpaid"
                paidMinor >= priceMinor -> "paid"
                paidMinor > 0 -> "partial"
                else -> "unpaid"
            }
            _sqlExec(
                "INSERT INTO transactions (id, type, created_at, customer_id, reference, note, payment_status, payment_method, paid_minor, currency_code) VALUES (?, 'sale', ?, NULL, NULL, NULL, ?, ?, ?, 'BDT')",
                listOf(txId, nowMs.toString(), status, paymentMethod, paidMinor.toString())
            )
            _sqlExec(
                "INSERT INTO transaction_lines (id, transaction_id, description, quantity, selling_price_minor, actual_cost_minor) VALUES (?, ?, ?, ?, ?, NULL)",
                listOf(lineId, txId, description, quantity.toString(), priceMinor.toString())
            )
            _recordAction("seed_sale")
            result.success(mapOf(
                "transactionId" to txId,
                "totalMinor" to priceMinor,
                "paidMinor" to paidMinor,
                "status" to status,
            ))
        } catch (e: Exception) {
            result.error("SEED_SALE_FAIL", e.message, null)
        }
    }

    // ----------------------------------------------------------------
    // SQLite helpers  — native Android SQLiteDatabase (device-safe)
    // ----------------------------------------------------------------
    private fun _openDb(): SQLiteDatabase {
        return SQLiteDatabase.openDatabase(
            _dbPath(),
            null,
            SQLiteDatabase.OPEN_READWRITE
        )
    }

    private fun _sqlCount(query: String): Int {
        val db = _openDb()
        return try {
            val cursor = db.rawQuery(query, null)
            val count = if (cursor.moveToFirst()) cursor.getInt(0) else 0
            cursor.close()
            count
        } finally {
            db.close()
        }
    }

    private fun _sqlLongOrNull(query: String): Long? {
        val db = _openDb()
        return try {
            val cursor = db.rawQuery(query, null)
            val result = if (cursor.moveToFirst()) cursor.getLong(0) else null
            cursor.close()
            result
        } finally {
            db.close()
        }
    }

    private fun _sqlExec(sql: String, args: List<String?> = emptyList()) {
        val db = _openDb()
        try {
            if (args.isEmpty()) {
                db.execSQL(sql)
            } else {
                db.execSQL(sql, args.toTypedArray())
            }
        } finally {
            db.close()
        }
    }

    // ----------------------------------------------------------------
    // Diagnostics log ( survives app restarts inside the same session )
    // ----------------------------------------------------------------
    private fun _recordAction(action: String) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US).format(Date())
            val log = File(filesDir, "debug_actions.log")
            log.appendText("$ts $action\n")
        } catch (_: Exception) {}
    }

    // ----------------------------------------------------------------
    // Native seed — creates DB schema + profile when intent fires,
    // before Flutter's MethodChannel is reachable.
    // ----------------------------------------------------------------
    private fun _nativeSeedProfile(intent: android.content.Intent?) {
        try {
            val name = intent?.getStringExtra("business_name") ?: "ADB Test Shop"
            val bizType = intent?.getStringExtra("business_type") ?: "retail"
            val dbPath = _dbPath()
            val db = SQLiteDatabase.openOrCreateDatabase(dbPath, null)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT)
            """)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS business_profile (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    workspace_kind TEXT NOT NULL,
                    business_type TEXT NOT NULL,
                    subtype TEXT,
                    phone TEXT,
                    address TEXT
                )
            """)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS transactions (
                    id TEXT PRIMARY KEY,
                    type TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    customer_id TEXT,
                    reference TEXT,
                    note TEXT,
                    payment_status TEXT NOT NULL,
                    payment_method TEXT,
                    paid_minor INTEGER NOT NULL,
                    currency_code TEXT NOT NULL DEFAULT 'BDT'
                )
            """)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS transaction_lines (
                    id TEXT PRIMARY KEY,
                    transaction_id TEXT NOT NULL,
                    description TEXT NOT NULL,
                    quantity REAL NOT NULL,
                    selling_price_minor INTEGER NOT NULL,
                    actual_cost_minor INTEGER,
                    FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
                )
            """)
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_transaction_lines_transaction_id ON transaction_lines(transaction_id)")
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)")
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id)")
            db.execSQL("DELETE FROM business_profile")
            val id = "adb-seeded-${System.currentTimeMillis()}"
            db.execSQL(
                "INSERT INTO business_profile (id, name, workspace_kind, business_type, subtype, phone, address) VALUES (?, ?, ?, ?, NULL, NULL, NULL)",
                arrayOf(id, name, "business", bizType)
            )
            db.close()
            _recordAction("seed_profile_native")
        } catch (e: Exception) {
            _recordAction("seed_profile_native_fail: ${e.message}")
        }
    }

    private fun _nativeSeedSale(intent: android.content.Intent?) {
        try {
            val description = intent?.getStringExtra("description") ?: "Test Item"
            val quantityStr = intent?.getStringExtra("quantity")
            val priceMinorStr = intent?.getStringExtra("priceMinor")
            val paidMinorStr = intent?.getStringExtra("paidMinor")
            val paymentMethod = intent?.getStringExtra("paymentMethod")
            val quantity = quantityStr?.toDoubleOrNull() ?: 1.0
            val priceMinor = priceMinorStr?.toIntOrNull() ?: 50000
            val paidMinor = paidMinorStr?.toIntOrNull() ?: priceMinor
            val nowMs = System.currentTimeMillis()
            val txId = "adb-sold-${nowMs}"
            val lineId = "$txId-l0"
            val dbPath = _dbPath()
            val status = when {
                priceMinor <= 0 -> "unpaid"
                paidMinor >= priceMinor -> "paid"
                paidMinor > 0 -> "partial"
                else -> "unpaid"
            }
            val db = SQLiteDatabase.openOrCreateDatabase(dbPath, null)
            db.execSQL(
                "INSERT INTO transactions (id, type, created_at, customer_id, reference, note, payment_status, payment_method, paid_minor, currency_code) VALUES (?, ?, ?, NULL, NULL, NULL, ?, ?, ?, 'BDT')",
                arrayOf(txId, "sale", nowMs.toString(), status, paymentMethod ?: "", paidMinor.toString())
            )
            db.execSQL(
                "INSERT INTO transaction_lines (id, transaction_id, description, quantity, selling_price_minor, actual_cost_minor) VALUES (?, ?, ?, ?, ?, NULL)",
                arrayOf(lineId, txId, description, quantity.toString(), priceMinor.toString())
            )
            db.close()
            _recordAction("seed_sale_native")
        } catch (e: Exception) {
            _recordAction("seed_sale_native_fail: ${e.message}")
        }
    }
}
