import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/sale/sale_service.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';

class ShareReceiptSheet extends StatelessWidget {
  const ShareReceiptSheet({super.key, required this.transaction, this.locale = AppLocale.bangla});

  final TransactionRecord transaction;
  final AppLocale locale;

  String t(String key) => AppText.get(locale, key);

  String money(int minor) {
    final taka = minorToTaka(minor);
    final display = locale == AppLocale.bangla ? toBanglaDigits(taka) : taka;
    return locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
  }

  String quantityText(double qty) {
    final text = qty == qty.truncateToDouble() ? qty.truncate().toString() : qty.toString();
    return locale == AppLocale.bangla ? toBanglaDigits(text) : text;
  }

  String typeLabel() {
    switch (transaction.type) {
      case TransactionType.expense: return t('transaction_type_expense');
      case TransactionType.purchase: return t('transaction_type_purchase');
      default: return t('sale_title');
    }
  }

  String _buildReceiptText() {
    final sb = StringBuffer();
    sb.writeln(t('receipt_header'));
    sb.writeln('─' * 30);
    sb.writeln('${t('date')}: ${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}');
    sb.writeln('${t('type')}: ${typeLabel()}');
    sb.writeln('─' * 30);
    for (final line in transaction.lines) {
      sb.writeln('${line.description} × ${quantityText(line.quantity)}');
      sb.writeln('  ${money(line.sellingPriceMinor)} cada');
    }
    sb.writeln('─' * 30);
    sb.writeln('${t('total')}: ${money(transaction.totalMinor)}');
    if (transaction.type != TransactionType.expense) {
      sb.writeln('${t('pay')}: ${money(transaction.paidMinor)}');
      if (transaction.dueMinor > 0) sb.writeln('${t('due')}: ${money(transaction.dueMinor)}');
    }
    sb.writeln('─' * 30);
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final text = _buildReceiptText();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('share_receipt'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
            child: SelectableText(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await SharePlus.instance.share(ShareParams(text: text));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.share),
            label: Text(t('share')),
          ),
        ],
      ),
    );
  }
}
