import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/sale/sale_service.dart';
import '../../domain/models/business_profile.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';
import '../customer/customer_list_screen.dart';
import '../expense/expense_entry_screen.dart';
import '../product/product_list_screen.dart';
import '../sale/sale_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../transaction/transaction_details_page.dart';

/// Owner workspace home: financial dashboard, action bar, and recent transactions.
class WorkspaceHomePage extends StatefulWidget {
  const WorkspaceHomePage({
    super.key,
    required this.services,
    this.locale = AppLocale.bangla,
    this.onLocaleChanged,
  });

  final AppServices services;
  final AppLocale locale;
  final ValueChanged<AppLocale>? onLocaleChanged;

  @override
  State<WorkspaceHomePage> createState() => _WorkspaceHomePageState();
}

class _WorkspaceHomePageState extends State<WorkspaceHomePage> {
  BusinessProfile? _profile;
  List<TransactionRecord> _transactions = const [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

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
    final profile = await widget.services.repository.getProfile();
    final transactions = await widget.services.repository.getTransactions();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final summary = await widget.services.repository.getFinancialSummary(from: todayStart);
    if (mounted) {
      setState(() {
        _profile = profile;
        _transactions = transactions;
        _summary = summary;
        _loading = false;
      });
    }
  }

  Future<void> _newSale() async {
    final record = await Navigator.of(context).push<TransactionRecord>(
      MaterialPageRoute<TransactionRecord>(
        builder: (_) => SaleEntryScreen(
          service: SaleEntryService(widget.services.repository, widget.services.diagnostics),
          locale: widget.locale,
        ),
      ),
    );
    if (record != null && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('sale_saved'))));
      }
    }
  }

  Future<void> _newExpense() async {
    final record = await Navigator.of(context).push<TransactionRecord>(
      MaterialPageRoute<TransactionRecord>(
        builder: (_) => ExpenseEntryScreen(
          service: SaleEntryService(widget.services.repository, widget.services.diagnostics),
          locale: widget.locale,
        ),
      ),
    );
    if (record != null && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('expense_saved'))));
      }
    }
  }

  Future<void> _newPurchase() async {
    final record = await Navigator.of(context).push<TransactionRecord>(
      MaterialPageRoute<TransactionRecord>(
        builder: (_) => ExpenseEntryScreen(
          service: SaleEntryService(widget.services.repository, widget.services.diagnostics),
          locale: widget.locale,
          defaultType: TransactionType.purchase,
        ),
      ),
    );
    if (record != null && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('purchase_saved'))));
      }
    }
  }

  void _openCustomers() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerListScreen(services: widget.services, locale: widget.locale),
      ),
    ).then((_) => _load());
  }

  void _openProducts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(services: widget.services, locale: widget.locale),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.name ?? t('app_name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: t('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  services: widget.services,
                  locale: widget.locale,
                  onLocaleChanged: widget.onLocaleChanged,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newSale,
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: Text(t('new_sale')),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildDashboard()),
                  SliverToBoxAdapter(child: _buildActionBar()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    sliver: _transactions.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildTransactionCard(_transactions[index]),
                              childCount: _transactions.length,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDashboard() {
    final sales = _summary['sales'] ?? 0;
    final expenses = _summary['expenses'] ?? 0;
    final profit = _summary['grossProfit'] ?? 0;
    final dues = _summary['outstandingDues'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('dashboard_sales_today'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(money(sales), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('dashboard_expenses_today'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(money(expenses), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('dashboard_profit'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      profit == 0 && sales == 0 ? t('no_financial_data') : money(profit),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: profit > 0 ? Colors.green : profit < 0 ? Colors.red : null,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('dashboard_outstanding_dues'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      dues > 0 ? money(dues) : t('no_financial_data'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: dues > 0 ? Colors.orange : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(Icons.sell_outlined, t('new_sale'), _newSale),
          _actionButton(Icons.emoji_objects, t('new_expense'), _newExpense),
          _actionButton(Icons.shopping_bag_outlined, t('new_purchase'), _newPurchase),
          _actionButton(Icons.people_outline, t('customers'), _openCustomers),
          _actionButton(Icons.inventory_2_outlined, t('products'), _openProducts),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(t('no_transactions'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t('no_transactions_hint'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionRecord transaction) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailsPage(transaction: transaction, locale: widget.locale),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      transaction.lines.first.description,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (transaction.lines.length > 1)
                    Text(
                      t('more_lines').replaceFirst('{count}', '${transaction.lines.length - 1}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(money(transaction.totalMinor), style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    t(transaction.paymentStatus.name == 'paid'
                        ? 'paid_status'
                        : transaction.paymentStatus.name == 'partial'
                            ? 'partial_status'
                            : 'unpaid_status'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              if (transaction.dueMinor > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${t('due')}: ${money(transaction.dueMinor)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
