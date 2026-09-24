import 'package:flutter/material.dart';

import '../../application/sale/sale_service.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';
import 'share_receipt_sheet.dart';

/// Displays all details of a saved sale transaction.
/// Completed sales are immutable — no edit/delete actions.
class TransactionDetailsPage extends StatelessWidget {
  const TransactionDetailsPage({
    super.key,
    required this.transaction,
    this.locale = AppLocale.bangla,
  });

  final TransactionRecord transaction;
  final AppLocale locale;

  String t(String key) => AppText.get(locale, key);

  String money(int minor) {
    final taka = minorToTaka(minor);
    final display = locale == AppLocale.bangla ? toBanglaDigits(taka) : taka;
    return locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
  }

  String quantityText(double qty) {
    final text = qty == qty.truncateToDouble()
        ? qty.truncate().toString()
        : qty.toString();
    return locale == AppLocale.bangla ? toBanglaDigits(text) : text;
  }

  @override
  Widget build(BuildContext context) {
    final total = transaction.totalMinor;
    final paid = transaction.paidMinor;
    final due = transaction.dueMinor;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('sale_title')),
        actions: [
          if (transaction.type == TransactionType.sale || transaction.type == TransactionType.serviceSale)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: t('share_receipt'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ShareReceiptSheet(
                  transaction: TransactionRecord(
                    id: '', type: TransactionType.sale, createdAt: DateTime.now(), lines: [],
                  ),
                  locale: locale,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              transaction.lines.first.description,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${t('total')}: ${money(total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              t('line_description'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final line in transaction.lines)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.description,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${t('quantity')}: ${quantityText(line.quantity)}'),
                          Text('${t('price')}: ${money(line.sellingPriceMinor)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t('line_total')),
                          Text(money(line.lineTotalMinor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('total'), style: Theme.of(context).textTheme.titleMedium),
                        Text(money(total), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('amount_paid')),
                        Text(money(paid)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('due')),
                        Text(
                          money(due),
                          style: TextStyle(
                            color: due > 0 ? Theme.of(context).colorScheme.error : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('payment_method')),
                        Text(
                          transaction.paymentMethod == null
                              ? t('payment_method_unset')
                              : t(transaction.paymentMethod!.name),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('paid_status')),
                        Text(
                          t(transaction.paymentStatus.name == 'paid'
                              ? 'paid_status'
                              : transaction.paymentStatus.name == 'partial'
                                  ? 'partial_status'
                                  : 'unpaid_status'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ID: ${transaction.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
