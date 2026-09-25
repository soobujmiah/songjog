import 'package:flutter/material.dart';

import '../../application/onboarding/onboarding_service.dart';
import '../../application/onboarding/workspace_fields.dart';
import '../../domain/models/business_profile.dart';
import '../../domain/services/diagnostic_collector.dart';
import '../../l10n/app_text.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.service,
    this.locale = AppLocale.bangla,
    this.diagnostics,
  });

  final OnboardingService service;
  final AppLocale locale;
  final DiagnosticCollector? diagnostics;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _subtype = TextEditingController();
  WorkspaceKind _workspaceKind = WorkspaceKind.business;
  BusinessType _businessType = BusinessType.retail;
  bool _saving = false;

  String t(String key) => AppText.get(widget.locale, key);

  String kindLabel(WorkspaceKind kind) {
    final key = kind == WorkspaceKind.business ? 'workspace_kind_business' : 'workspace_kind_institution';
    return t(key);
  }

  String businessTypeLabel(BusinessType type) {
    // type.name is the camelCase enum identifier (e.g. "generalShop"); the
    // translation keys in AppText are snake_case ("business_type_general_shop").
    final suffix = type.name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
    return t('business_type_$suffix');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _subtype.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final profile = await widget.service.createOwnerWorkspace(
        name: _name.text,
        workspaceKind: _workspaceKind,
        businessType: _businessType,
        phone: _phone.text,
        address: _address.text,
        subtype: _subtype.text,
      );
      widget.diagnostics?.record(
        level: 'info',
        category: 'onboarding',
        operation: 'onboarding_save',
        message: 'owner workspace created',
        details: {
          'workspace_kind': profile.workspaceKind.name,
          'business_type': profile.businessType.name,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError catch (error, stack) {
      widget.diagnostics?.record(
        level: 'error',
        category: 'onboarding',
        operation: 'onboarding_save',
        message: 'onboarding save rejected',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? '')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = WorkspaceFieldRegistry.forBusinessType(_businessType).fields;
    return Scaffold(
      appBar: AppBar(title: Text(t('workspace_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t('workspace_name'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(controller: _name, textInputAction: TextInputAction.next),
            const SizedBox(height: 20),
            DropdownButtonFormField<WorkspaceKind>(
              initialValue: _workspaceKind,
              decoration: InputDecoration(labelText: t('workspace_type')),
              items: WorkspaceKind.values.map((kind) => DropdownMenuItem(
                value: kind,
                child: Text(kindLabel(kind)),
              )).toList(),
              onChanged: (value) => setState(() => _workspaceKind = value!),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<BusinessType>(
              initialValue: _businessType,
              decoration: InputDecoration(labelText: t('business_type')),
              items: BusinessType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(businessTypeLabel(type)),
              )).toList(),
              onChanged: (value) => setState(() => _businessType = value!),
            ),
            const SizedBox(height: 20),
            if (fields.contains(OnboardingField.phone)) ...[
              TextField(controller: _phone, keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: t('phone'))),
              const SizedBox(height: 16),
            ],
            if (fields.contains(OnboardingField.address)) ...[
              TextField(controller: _address, decoration: InputDecoration(labelText: t('address'))),
              const SizedBox(height: 16),
            ],
            if (fields.contains(OnboardingField.subtype)) ...[
              TextField(controller: _subtype, decoration: InputDecoration(labelText: t('subtype'))),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (context, value, _) => FilledButton(
                onPressed:
                    _saving || value.text.trim().isEmpty ? null : _save,
                child: Text(_saving ? '…' : t('continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
