import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/sale/sale_service.dart';
import '../../domain/models/transaction.dart';
import '../../l10n/app_text.dart';

class _LineState {
  _LineState({this.locale = AppLocale.bangla, this.includeCost = false});

  final AppLocale locale;
  final bool includeCost;
  final description = TextEditingController();
  final quantity = TextEditingController();
  final price = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
    cost.dispose();
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

  int? get parsedCostMinor {
    if (!includeCost) return null;
    final text = cost.text.trim();
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
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (locale != AppLocale.bangla) return newValue;
    final converted = toBanglaDigits(newValue.text);
    return newValue.copyWith(text: converted, composing: TextRange.empty);
  }
}

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({
    super.key,
    required this.service,
    this.locale = AppLocale.bangla,
    this.defaultType = TransactionType.expense,
  });

  final SaleEntryService service;
  final AppLocale locale;
  final TransactionType defaultType;

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  late final List<_LineState> _lines = [_LineState(locale: widget.locale, includeCost: widget.defaultType == TransactionType.purchase)];
  final _paid = TextEditingController();
  PaymentMethod? _method;
  bool _saving = false;

  String t(String key) => AppText.get(widget.locale, key);

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
    if (line.includeCost) line.cost.addListener(_onFieldChanged);
  }

  void _detachLineListeners(_LineState line) {
    line.description.removeListener(_onFieldChanged);
    line.quantity.removeListener(_onFieldChanged);
    line.price.removeListener(_onFieldChanged);
    if (line.includeCost) line.cost.removeListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _addLine() {
    final newLine = _LineState(locale: widget.locale, includeCost: widget.defaultType == TransactionType.purchase);
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

  int get _totalMinor => _lines.fold<int>(0, (sum, line) => sum + (line.lineTotalMinor ?? 0));

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

  Future<void> _complete() async {
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
              costMinor: line.parsedCostMinor,
            ),
        ],
        paidMinor: paid,
        paymentMethod: _method,
        type: widget.defaultType,
      );
      if (mounted) Navigator.of(context).pop(record);
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('sale_failed'))));
  }

  @override
  void dispose() {
    for (final line in _lines) {
      _detachLineListeners(line);
    }
    _paid.removeListener(_onFieldChanged);
    _paid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalMinor;
    return Scaffold(
      appBar: AppBar(title: Text(widget.defaultType == TransactionType.expense ? t('new_expense') : t('new_purchase'))),
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
                        Text(t('total'), style: Theme.of(context).textTheme.titleMedium),
                        Text(money(total), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paid,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]')),
                        _BanglaDigitFormatter(widget.locale),
                      ],
                      decoration: InputDecoration(labelText: t('pay')),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<PaymentMethod?>(
                      initialValue: _method,
                      decoration: InputDecoration(labelText: t('payment_method')),
                      items: [
                        DropdownMenuItem<PaymentMethod?>(value: null, child: Text(t('payment_method_unset'))),
                        for (final method in PaymentMethod.values)
                          DropdownMenuItem<PaymentMethod?>(value: method, child: Text(t(method.name))),
                      ],
                      onChanged: _saving ? null : (value) => setState(() => _method = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving || !_allLinesComplete ? null : _complete,
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
                  onPressed: _saving || _lines.length == 1 ? null : () => _removeLine(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]')),
                      _BanglaDigitFormatter(widget.locale),
                    ],
                    decoration: InputDecoration(labelText: t('quantity')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: line.price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]')),
                      _BanglaDigitFormatter(widget.locale),
                    ],
                    decoration: InputDecoration(labelText: t('price')),
                  ),
                ),
              ],
            ),
            if (line.includeCost) ...[
              const SizedBox(height: 8),
              TextField(
                controller: line.cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]')),
                  _BanglaDigitFormatter(widget.locale),
                ],
                decoration: InputDecoration(labelText: t('product_cost')),
              ),
            ],
            if (lineTotal != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('line_total'), style: Theme.of(context).textTheme.labelLarge),
                    Text(money(lineTotal), style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
