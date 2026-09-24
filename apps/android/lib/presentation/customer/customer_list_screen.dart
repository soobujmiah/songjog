import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/models/customer.dart';
import '../../l10n/app_text.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, required this.services, this.locale = AppLocale.bangla});

  final AppServices services;
  final AppLocale locale;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Customer> _customers = const [];
  bool _loading = true;
  String t(String key) => AppText.get(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customers = await widget.services.repository.getCustomers();
    if (mounted) setState(() { _customers = customers; _loading = false; });
  }

  Future<void> _addCustomer() async {
    final result = await showDialog<Customer?>(
      context: context,
      builder: (ctx) => _AddCustomerDialog(locale: widget.locale),
    );
    if (result != null && mounted) {
      await widget.services.repository.saveCustomer(result);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('customer_saved'))));
    }
  }

  void _openDetail(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDetailScreen(customer: customer, services: widget.services, locale: widget.locale),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('customers'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _addCustomer,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.people_outline, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(t('no_customers'), style: Theme.of(context).textTheme.titleMedium),
                  ]),
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c.name),
                        subtitle: c.phone != null ? Text(c.phone!) : null,
                        onTap: () => _openDetail(c),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog({this.locale = AppLocale.bangla});
  final AppLocale locale;
  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String t(String key) => AppText.get(widget.locale, key);

  @override
  void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('add_customer')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: t('customer_name'))),
        const SizedBox(height: 8),
        TextField(controller: _phone, decoration: InputDecoration(labelText: t('customer_phone'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('skip'))),
        FilledButton(onPressed: () {
          if (_name.text.trim().isEmpty) return;
          Navigator.pop(context, Customer(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          ));
        }, child: Text(t('save'))),
      ],
    );
  }
}
