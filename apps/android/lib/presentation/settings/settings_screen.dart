import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/services/export_payload.dart';
import '../../domain/services/export_type.dart';
import '../../l10n/app_text.dart';

/// Settings & tools surface. Hosts the mandatory user-facing export entry
/// points (user data and diagnostics) plus debug-only diagnostics controls
/// and language toggle.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    this.locale = AppLocale.bangla,
    this.onLocaleChanged,
  });

  final AppServices services;
  final AppLocale locale;
  final ValueChanged<AppLocale>? onLocaleChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  String t(String key) => AppText.get(widget.locale, key);

  String localeName(AppLocale locale) => t(locale == AppLocale.bangla ? 'language_bangla' : 'language_english');

  Future<void> _runExport(ExportType type) async {
    setState(() => _busy = true);
    final operation = 'export_${type.name}';
    try {
      final payload = await widget.services.exportService.export(
        ExportRequest(type: type),
      );
      final adapter = await widget.services.exportFileAdapter();
      final path = await adapter.save(payload);
      widget.services.diagnostics.record(
        level: 'info',
        category: 'export',
        operation: operation,
        message: 'export saved',
        details: {
          'file': payload.filename,
          'mime_type': payload.mimeType,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('export_saved')),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: t('share'),
            onPressed: () => _share(path, payload),
          ),
        ),
      );
    } catch (error, stack) {
      widget.services.diagnostics.record(
        level: 'error',
        category: 'export',
        operation: operation,
        message: 'export failed',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('export_failed')} — ${error.toString()}'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(String path, ExportPayload payload) async {
    final completed = await widget.services.shareService.shareFile(
      path: path,
      mimeType: payload.mimeType,
      title: payload.filename,
    );
    widget.services.diagnostics.record(
      level: completed ? 'info' : 'warning',
      category: 'export',
      operation: 'share_export',
      message: completed ? 'share dispatched' : 'share not completed',
      details: {'file': payload.filename},
    );
  }

  void _recordTestEvent() {
    widget.services.diagnostics.record(
      level: 'warning',
      category: 'other',
      operation: 'test_event',
      message: 'controlled test diagnostic event (requested from settings)',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('test_event_recorded'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return Scaffold(
      appBar: AppBar(title: Text(t('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            t('language'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<AppLocale>(
              groupValue: widget.locale,
              onChanged: (value) {
                if (value != null) {
                  // Capture the navigator synchronously (no BuildContext use after the async
                  // gap below -- avoids use_build_context_synchronously) and defer the pop to
                  // a microtask so the parent's setState propagates first.
                  final navigator = Navigator.of(context);
                  widget.onLocaleChanged?.call(value);
                  Future.microtask(navigator.pop);
                }
              },
              child: Column(
                children: [
                  RadioListTile<AppLocale>(
                    title: Text(t('language_bangla')),
                    value: AppLocale.bangla,
                  ),
                  const Divider(height: 1),
                  RadioListTile<AppLocale>(
                    title: Text(t('language_english')),
                    value: AppLocale.english,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('export_section'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(t('export_my_data')),
                  subtitle: Text(t('export_my_data_hint')),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: busy ? null : () => _runExport(ExportType.userData),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(t('export_diagnostics')),
                  subtitle: Text(t('export_diagnostics_hint')),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: busy ? null : () => _runExport(ExportType.diagnostic),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(t('record_test_event')),
                onTap: _recordTestEvent,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${t('version')} ${widget.services.appVersionLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
