package com.songjog.songjog

import android.content.pm.PackageManager
import android.os.Bundle
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
                val flags = packageManagergetApplicationInfo(packageName, 0).flags
                result.success((flags and PackageManager.FLAG_DEBUGGABLE) != 0)
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
            val dbPath = filesDir.resolve("songjog.db").absolutePath
            val profiles = _sqlCount(dbPath, "SELECT COUNT(*) FROM business_profile")
            val transactions = _sqlCount(dbPath, "SELECT COUNT(*) FROM transactions")
            val lastTotal = _sqlLongOrNull(
                dbPath,
                "SELECT COALESCE(MAX(paid_minor + (total_minor - paid_minor)), 0) FROM transactions"
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
            val db = filesDir.resolve("songjog.db")
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
            val dbPath = filesDir.resolve("songjog.db").absolutePath
            // Remove any existing profile first (idempotent).
            _sqlExec(dbPath, "DELETE FROM business_profile")
            val id = "adb-seeded-${System.currentTimeMillis()}"
            _sqlExec(dbPath, """
                INSERT INTO business_profile
                    (id, name, workspace_kind, business_type, subtype, phone, address)
                VALUES (?, ?, ?, ?, NULL, NULL, NULL)
            """, listOf(id, name, "business", bizType))
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
            val dbPath = filesDir.resolve("songjog.db").absolutePath
            // Compute payment status deterministically.
            val status = when {
                priceMinor <= 0 -> "unpaid"
                paidMinor >= priceMinor -> "paid"
                paidMinor > 0 -> "partial"
                else -> "unpaid"
            }
            _sqlExec(dbPath, """
                INSERT INTO transactions
                    (id, type, created_at, customer_id, reference, note,
                     payment_status, payment_method, paid_minor, currency_code)
                VALUES (?, 'sale', ?, NULL, NULL, NULL, ?, ?, ?, 'BDT')
            """, listOf(txId, nowMs, status, paymentMethod, paidMinor))
            _sqlExec(dbPath, """
                INSERT INTO transaction_lines
                    (id, transaction_id, description, quantity, selling_price_minor, actual_cost_minor)
                VALUES (?, ?, ?, ?, ?, NULL)
            """, listOf(lineId, txId, description, quantity, priceMinor))
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
    // SQLite helpers  — direct file access via run-as style subprocess
    // ----------------------------------------------------------------
    private fun _sqliteBin(): String {
        // Prefer the bundled sqlite3 from the Android SDK toolchain, falling back
        // to the system one if present.
        val sdkRoot = System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT")
        if (sdkRoot != null) {
            val candidate = File(sdkRoot, "platform-tools/sqlite3")
            if (candidate.exists()) return candidate.absolutePath
        }
        return "/home/sbj/android-sdk/platform-tools/sqlite3"
    }

    private fun _sqlExec(dbPath: String, sql: String, args: List<Any>? = null) {
        val cmd = buildList {
            add(_sqliteBin())
            add(dbPath)
            val stmt = if (args == null) sql else {
                var s = sql
                args.forEach { s = s.replaceFirst("?", "'${it}'") }
                s
            }
            add(stmt)
        }
        val exit = ProcessBuilder(*cmd.toTypedArray())
            .redirectErrorStream(true)
            .start()
            .waitFor()
        if (exit != 0) throw RuntimeException("sqlite3 exited $exit")
    }

    private fun _sqlCount(dbPath: String, sql: String): Int {
        val out = _sqlQuery(dbPath, sql)
        return out.trim().toIntOrNull() ?: throw RuntimeException("unexpected sqlite output: $out")
    }

    private fun _sqlLongOrNull(dbPath: String, sql: String): Long? {
        val out = _sqlQuery(dbPath, sql).trim()
        return if (out.isEmpty() || out == "None") null else out.toLongOrNull()
    }

    private fun _sqlQuery(dbPath: String, sql: String): String {
        val cmd = arrayOf(_sqliteBin(), dbPath, sql)
        val proc = ProcessBuilder(*cmd)
            .redirectErrorStream(true)
            .start()
        val output = proc.inputStream.bufferedReader().readText()
        val exit = proc.waitFor()
        if (exit != 0) throw RuntimeException("sqlite3 exited $exit: $output")
        return output
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
}
