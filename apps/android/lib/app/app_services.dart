import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/onboarding/onboarding_service.dart';
import '../data/export/app_diagnostic_report_source.dart';
import '../data/export/local_export_file_adapter.dart';
import '../data/export/share_service.dart';
import '../data/local/in_memory_store.dart';
import '../data/local/persistent_diagnostic_log.dart';
import '../data/local/sqlite_store.dart';
import '../data/repositories/business_repository.dart';
import '../domain/services/diagnostic_collector.dart';
import '../domain/services/diagnostic_store.dart';
import '../domain/services/export_payload.dart';
import '../domain/services/export_service_impl.dart';
import '../l10n/app_text.dart';

/// Composition root: constructs and owns the application's services.
///
/// [create] performs real platform wiring (SQLite, path_provider,
/// package/device info). Tests construct [AppServices] directly with fakes
/// and temporary paths.
class AppServices {
  AppServices({
    required this.store,
    required this.repository,
    required this.onboarding,
    required this.diagnostics,
    required this.exportService,
    required this.diagnosticsReportSource,
    required this.shareService,
    required this.exportFileAdapter,
    required this.appVersionLabel,
    AppLocale locale = AppLocale.bangla,
  }) : _locale = locale;

  /// Durable (or in-memory fallback) business data store.
  final LocalStore store;

  final BusinessRepository repository;
  final OnboardingService onboarding;
  final DiagnosticCollector diagnostics;

  /// Export service. Diagnostic exports use [diagnosticsReportSource].
  final DefaultExportService exportService;
  final DiagnosticReportSource diagnosticsReportSource;
  final ShareService shareService;

  /// Resolves the export file adapter. In production this writes into the
  /// user-visible exports directory (app-specific external storage on
  /// Android, falling back to the app documents directory); tests inject a
  /// fake adapter without real I/O.
  final Future<ExportFileAdapter> Function() exportFileAdapter;

  /// Human-readable version/build label, e.g. `0.1.0 (1)`.
  final String appVersionLabel;

  AppLocale _locale;
  AppLocale get currentLocale => _locale;

  void setLocale(AppLocale locale) => _locale = locale;

  static Future<AppServices> create({AppLocale locale = AppLocale.bangla}) async {
    // Persistent diagnostic log, wired before any work that may fail so the
    // failure itself is recorded and survives a crash.
    late PersistentDiagnosticLog diagnosticLog;
    var diagnosticLogReady = false;
    final eventStore = DiagnosticStore();
    final collector = DiagnosticCollector(
      store: eventStore,
      persist: (event) {
        if (!diagnosticLogReady) return Future<void>.value();
        return diagnosticLog.append(event);
      },
    );

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      diagnosticLog = PersistentDiagnosticLog(
        File(p.join(docsDir.path, 'diagnostics.jsonl')),
      );
      await diagnosticLog.load();
      for (final event in diagnosticLog.events) {
        eventStore.add(event);
      }
      diagnosticLogReady = true;
    } catch (error, stack) {
      collector.record(
        level: 'warning',
        category: 'lifecycle',
        operation: 'diagnostic_log_init',
        message: 'persistent diagnostic log unavailable; in-memory only',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
    }

    LocalStore dataStore;
    try {
      dataStore = await SqliteStore.open();
      collector.record(
        level: 'info',
        category: 'database',
        operation: 'database_open',
        message: 'SQLite database opened',
      );
    } catch (error, stack) {
      collector.record(
        level: 'error',
        category: 'database',
        operation: 'database_open',
        message: 'SQLite open failed; falling back to in-memory store',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
      dataStore = InMemoryStore();
    }

    collector.record(
      level: 'info',
      category: 'lifecycle',
      operation: 'app_start',
      message: 'application started',
    );

    final repository = DefaultBusinessRepository(dataStore);
    final onboarding = OnboardingService(repository);

    var appVersionLabel = kFallbackPackageInfo;
    var platform = 'unknown';
    var deviceModel = 'unknown';
    var osVersion = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersionLabel = formatPackageInfo(packageInfo);
      collector.record(
        level: 'info',
        category: 'lifecycle',
        operation: 'package_info',
        message: 'package info captured',
        details: {
          'version': packageInfo.version,
          'build_number': packageInfo.buildNumber,
        },
      );
    } catch (error) {
      collector.record(
        level: 'warning',
        category: 'lifecycle',
        operation: 'package_info',
        message: 'package info unavailable',
        error: error.toString(),
      );
    }

    try {
      if (Platform.isAndroid) {
        platform = 'android';
        final android = await DeviceInfoPlugin().androidInfo;
        deviceModel =
            '${android.brand} ${android.model} (${android.device})'.trim();
        osVersion = '${android.version.release} (SDK ${android.version.sdkInt})';
      } else {
        platform = Platform.operatingSystem;
      }
    } catch (error) {
      collector.record(
        level: 'warning',
        category: 'lifecycle',
        operation: 'device_info',
        message: 'device info unavailable',
        error: error.toString(),
      );
    }

    final reportSource = AppDiagnosticReportSource(
      collector: collector,
      appVersion: _versionPart(appVersionLabel),
      buildNumber: _buildNumberPart(appVersionLabel),
      platform: platform,
      deviceModel: deviceModel,
      osVersion: osVersion,
      locale: locale == AppLocale.bangla ? 'bn' : 'en',
      runtimeMode: _runtimeMode(),
    );

    return AppServices(
      store: dataStore,
      repository: repository,
      onboarding: onboarding,
      diagnostics: collector,
      exportService: DefaultExportService(
        store: dataStore,
        reportSource: reportSource,
      ),
      diagnosticsReportSource: reportSource,
      shareService: const AndroidShareService(),
      exportFileAdapter: () async =>
          LocalExportFileAdapter(directory: await _defaultExportsDirectory()),
      appVersionLabel: appVersionLabel,
    );
  }

  static Future<Directory> _defaultExportsDirectory() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(base.path, 'exports'));
    await exports.create(recursive: true);
    return exports;
  }

  static String _versionPart(String label) {
    final close = label.lastIndexOf(' (');
    return close > 0 ? label.substring(0, close) : label;
  }

  static String _buildNumberPart(String label) {
    final open = label.indexOf(' (');
    final close = label.lastIndexOf(')');
    if (open > 0 && close > open) {
      return label.substring(open + 2, close);
    }
    return '0';
  }

  static String _runtimeMode() {
    if (kDebugMode) return 'debug';
    if (kProfileMode) return 'profile';
    return 'release';
  }
}
