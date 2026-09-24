import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/sale/sale_service.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer, required this.services, this.locale = AppLocale.bangla});

  final Customer customer;
  final AppServices services;
  final AppLocale locale;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<TransactionRecord> _transactions = const [];
  bool _loading = true;
  bool _deleting = false;
  String t(String key) => AppText.get(widget.locale, key);

  String money(int minor) {
    final taka = minorToTaka(minor);
    final display = widget.locale == AppLocale.bangla ? toBanglaDigits(taka) : taka;
    return widget.locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.services.repository.getTransactions();
    final filtered = all.where((tx) => tx.customerId == widget.customer.id).toList();
    if (mounted) setState(() { _transactions = filtered; _loading = false; });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('confirm_delete')),
        content: Text('${t('delete_customer')} ${widget.customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('skip'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('confirm_delete'))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _deleting = true);
      await widget.services.repository.deleteCustomer(widget.customer.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: t('delete_customer'),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.customer.phone != null)
                          Text('${t('customer_phone')}: ${widget.customer.phone}', style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        FutureBuilder<int>(
                          future: widget.services.repository.getCustomerOpenBalance(widget.customer.id),
                          builder: (ctx, snap) {
                            if (snap.data == null) return const SizedBox.shrink();
                            return Text('${t('open_balance')}: ${money(snap.data!)}', style: Theme.of(context).textTheme.titleMedium);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t('workspace_home_recent'), style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                if (_transactions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(t('no_customer_transactions'))),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(_transactions[index].lines.first.description),
                          subtitle: Text(money(_transactions[index].totalMinor)),
                          trailing: Text(t(_transactions[index].paymentStatus.name == 'paid' ? 'paid_status' : 'unpaid_status')),
                        ),
                      ),
                      childCount: _transactions.length,
                    ),
                  ),
              ],
            ),
    );
  }
}
