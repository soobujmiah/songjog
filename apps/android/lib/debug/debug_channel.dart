import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Deterministic test-control surface for ADB-first device validation.
///
/// **Build-gated**: only [isAvailable] is true when `kDebugMode` AND
/// `FLAG_DEBUGGABLE` is set on the Android package (both are true for
/// `flutter run --debug` and CI debug APKs; false for release builds).
///
/// **Scopes**: reset-app (atomic, destructive), state query (read-only),
/// seed-profile / seed-sale (idempotent writes with deterministic IDs so
/// results can be asserted afterwards).
///
/// Caller's responsibility to check [isAvailable] before invoking any
/// method; doing so in a release build throws [UnsupportedError].
class DebugChannel {
  static const _channel = MethodChannel('com.songjog/debug');

  DebugChannel._();

  /// True when this layer is wired up and the native handler responded.
  /// Always false in a release build regardless of connectivity.
  static Future<bool> get isAvailable async {
    if (!kDebugMode) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('queryApp', {'key': 'isDebuggable'});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Clears the entire app sandbox (SQLite, export files, diagnostics log)
  /// and returns the new process ID so callers can wait for the restart.
  static Future<int> resetApp() async {
    await _check();
    final pid = await _channel.invokeMethod<int>('resetApp') ?? -1;
    return pid;
  }

  /// Creates or overwrites the business profile with deterministic fields so
  /// downstream tests never have to rely on onboarding taps.
  static Future<Map<String, dynamic>> seedProfile({
    String name = 'ADB Test Shop',
    String businessType = 'retail',
  }) async {
    await _check();
    final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>('seedProfile', {
      'name': name,
      'businessType': businessType,
    });
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// Appends a single sale transaction with well-known values.
  /// Call after [seedProfile]; use [queryState] after to assert what was persisted.
  static Future<void> seedSale({
    String description = 'Test Product',
    double quantity = 2.0,
    int priceMinor = 50000,
    int paidMinor = 50000,
    String? paymentMethod,
  }) async {
    await _check();
    await _channel.invokeMethod<void>('seedSale', {
      'description': description,
      'quantity': quantity,
      'priceMinor': priceMinor,
      'paidMinor': paidMinor,
      'paymentMethod': paymentMethod,
    });
  }

  /// Returns a JSON map with profile + transactions counts + last-sale total.
  /// Keys: `profileCount`, `transactionCount`, `lastTransactionTotalMinor`.
  static Future<Map<String, dynamic>> queryState() async {
    await _check();
    final raw = await _channel.invokeMethod<dynamic>('queryState');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('unexpected queryState response: $raw');
  }

  static Future<void> _check() async {
    if (!kDebugMode) {
      throw UnsupportedError(
          'DebugChannel is disabled outside debug builds. '
          'Call isAvailable first.');
    }
    final available = await isAvailable;
    if (!available) {
      throw StateError(
          'DebugChannel not reachable — app may be running in profile/release, '
          'or the native side has crashed.');
    }
  }
}
