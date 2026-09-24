import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/sale/sale_service.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';

class _LineState {
  _LineState({this.locale = AppLocale.bangla}) {
    quantity.text = locale == AppLocale.bangla ? '১' : '1';
  }

  final AppLocale locale;
  final description = TextEditingController();
  final quantity = TextEditingController();
  final price = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }

  bool get hasDescription => description.text.trim().isNotEmpty;

  double? get parsedQuantity {
    final latin = toLatinDigits(quantity.text.trim());
    final value = double.tryParse(latin);
    return (value == null || value <= 0) ? null : value;
  }

  int? get parsedPriceMinor {
    final text = price.text.trim();
    if (text.isEmpty) return null;
    try {
      final minor = takaToMinor(text);
      return minor <= 0 ? null : minor;
    } on FormatException {
      return null;
    }
  }

  int? get lineTotalMinor {
    final q = parsedQuantity;
    final p = parsedPriceMinor;
    if (q == null || p == null) return null;
    return (p * q).round();
  }

  bool get complete => hasDescription && lineTotalMinor != null;
}

class _BanglaDigitFormatter extends TextInputFormatter {
  _BanglaDigitFormatter(this.locale);
  final AppLocale locale;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (locale != AppLocale.bangla) return newValue;
    // Allow both Latin and Bangla digits, but display as Bangla in bn mode
    final converted = toBanglaDigits(newValue.text);
    return newValue.copyWith(
      text: converted,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class SaleEntryScreen extends StatefulWidget {
  const SaleEntryScreen({
    super.key,
    required this.service,
    this.locale = AppLocale.bangla,
  });

  final SaleEntryService service;
  final AppLocale locale;

  @override
  State<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends State<SaleEntryScreen> {
  late final List<_LineState> _lines = [
    _LineState(locale: widget.locale),
  ];
  final _paid = TextEditingController();
  PaymentMethod? _method;
  bool _saving = false;

  String t(String key) => AppText.get(widget.locale, key);

  /// Currency prefix keeps script purity: Bangla mode uses the taka sign,
  /// English mode stays Latin-only. In Bangla mode, digits use Bangla numerals.
  String money(int minor) {
    final taka = minorToTaka(minor);
    final display = widget.locale == AppLocale.bangla ? toBanglaDigits(taka) : taka;
    return widget.locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
  }

  @override
  void initState() {
    super.initState();
    _attachLineListeners(_lines.first);
    _paid.addListener(_onFieldChanged);
  }

  void _attachLineListeners(_LineState line) {
    line.description.addListener(_onFieldChanged);
    line.quantity.addListener(_onFieldChanged);
    line.price.addListener(_onFieldChanged);
  }

  void _detachLineListeners(_LineState line) {
    line.description.removeListener(_onFieldChanged);
    line.quantity.removeListener(_onFieldChanged);
    line.price.removeListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _addLine() {
    final newLine = _LineState(locale: widget.locale);
    _attachLineListeners(newLine);
    setState(() => _lines.add(newLine));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final removed = _lines.removeAt(index);
    _detachLineListeners(removed);
    removed.dispose();
    setState(() {});
  }

  @override
  void dispose() {
    for (final line in _lines) {
      _detachLineListeners(line);
      line.dispose();
    }
    _paid.removeListener(_onFieldChanged);
    _paid.dispose();
    super.dispose();
  }

  int get _totalMinor =>
      _lines.fold<int>(0, (sum, line) => sum + (line.lineTotalMinor ?? 0));

  int? get _paidMinor {
    final text = _paid.text.trim();
    if (text.isEmpty) return 0;
    try {
      return takaToMinor(text);
    } on FormatException {
      return null;
    }
  }

  bool get _allLinesComplete => _lines.isNotEmpty && _lines.every((l) => l.complete);

  PaymentStatus get _status {
    final total = _totalMinor;
    final paid = _paidMinor;
    if (paid == null) return PaymentStatus.unpaid;
    return derivePaymentStatus(
        totalMinor: total, paidMinor: clampPaid(paid, total));
  }

  Future<void> _completeSale() async {
    final paid = _paidMinor;
    if (paid == null) {
      _showError();
      return;
    }
    setState(() => _saving = true);
    try {
      final record = await widget.service.saveSale(
        lines: [
          for (final line in _lines)
            (
              description: line.description.text.trim(),
              quantity: line.parsedQuantity!,
              priceMinor: line.parsedPriceMinor!,
              costMinor: null,
            ),
        ],
        paidMinor: clampPaid(paid, _totalMinor),
        paymentMethod: _method,
      );
      if (mounted) {
        Navigator.of(context).pop(record);
      }
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('sale_failed'))));
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalMinor;
    final paid = _paidMinor ?? 0;
    final clampedPaid = clampPaid(paid, total);
    final due = total - clampedPaid;
    final returnable = calculateReturnable(paid, total);
    return Scaffold(
      appBar: AppBar(title: Text(t('sale_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (var i = 0; i < _lines.length; i++) ...[
              _buildLine(_lines[i], index: i),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              onPressed: _saving ? null : _addLine,
              icon: const Icon(Icons.add),
              label: Text(t('add_line')),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('total'),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(money(total),
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paid,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\u09E6-\u09EF.]')),
                        _BanglaDigitFormatter(widget.locale),
                      ],
                      decoration: InputDecoration(
                        labelText: t('amount_paid'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('due'),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          money(due),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: due > 0
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                        ),
                      ],
                    ),
                    if (returnable > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t('returnable'),
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            money(returnable),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('change_due'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      t(_status.name == 'paid'
                          ? 'paid_status'
                          : _status.name == 'partial'
                              ? 'partial_status'
                              : 'unpaid_status'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod?>(
                      initialValue: _method,
                      decoration: InputDecoration(labelText: t('payment_method')),
                      items: [
                        DropdownMenuItem<PaymentMethod?>(
                          value: null,
                          child: Text(t('payment_method_unset')),
                        ),
                        for (final method in PaymentMethod.values)
                          DropdownMenuItem<PaymentMethod?>(
                            value: method,
                            child: Text(t(method.name)),
                          ),
                      ],
                      onChanged:
                          _saving ? null : (value) => setState(() => _method = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _saving || !_allLinesComplete ? null : _completeSale,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_saving ? '…' : t('complete_sale')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(_LineState line, {required int index}) {
    final lineTotal = line.lineTotalMinor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: line.description,
                    decoration: InputDecoration(labelText: t('line_description')),
                  ),
                ),
                IconButton(
                  tooltip: t('remove_line'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      _saving || _lines.length == 1 ? null : () => _removeLine(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9\u09E6-\u09EF.]')),
                      _BanglaDigitFormatter(widget.locale),
                    ],
                    decoration: InputDecoration(labelText: t('quantity')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: line.price,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9\u09E6-\u09EF.]')),
                      _BanglaDigitFormatter(widget.locale),
                    ],
                    decoration: InputDecoration(labelText: t('price')),
                  ),
                ),
              ],
            ),
            if (lineTotal != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('line_total'),
                        style: Theme.of(context).textTheme.labelLarge),
                    Text(money(lineTotal),
                        style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
