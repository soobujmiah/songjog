import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/sale/sale_service.dart';
import '../../domain/models/product.dart';
import '../../l10n/app_text.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.services, this.locale = AppLocale.bangla});

  final AppServices services;
  final AppLocale locale;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product> _products = const [];
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
    final products = await widget.services.repository.getProducts();
    if (mounted) setState(() { _products = products; _loading = false; });
  }

  Future<void> _addProduct() async {
    final result = await showModalBottomSheet<Product?>(
      context: context,
      builder: (ctx) => _ProductBottomSheet(locale: widget.locale),
    );
    if (result != null && mounted) {
      await widget.services.repository.saveProduct(result);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('product_saved'))));
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('confirm_delete')),
        content: Text('${t('delete_product')} ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('skip'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('confirm_delete'))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.services.repository.deleteProduct(product.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('products'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _addProduct,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.inventory_2_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(t('no_products'), style: Theme.of(context).textTheme.titleMedium),
                  ]),
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return Dismissible(
                      key: Key(p.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteProduct(p),
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
                          title: Text(p.name),
                          subtitle: p.category != null ? Text(p.category!) : null,
                          trailing: Text(money(p.sellingPriceMinor)),
                          onTap: () => _deletePrompt(p),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _deletePrompt(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (product.category != null) Text('Categoria: ${product.category}'),
          Text('Preço: ${money(product.sellingPriceMinor)}'),
          if (product.costPriceMinor != null) Text('Custo: ${money(product.costPriceMinor!)}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('skip'))),
          FilledButton.tonal(onPressed: () { Navigator.pop(ctx); _deleteProduct(product); }, child: Text(t('delete_product'))),
        ],
      ),
    );
  }
}

class _ProductBottomSheet extends StatefulWidget {
  const _ProductBottomSheet({this.locale = AppLocale.bangla});
  final AppLocale locale;
  @override
  State<_ProductBottomSheet> createState() => _ProductBottomSheetState();
}

class _ProductBottomSheetState extends State<_ProductBottomSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _category = TextEditingController();
  String t(String key) => AppText.get(widget.locale, key);

  @override
  void dispose() { _name.dispose(); _price.dispose(); _cost.dispose(); _category.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('new_product'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: InputDecoration(labelText: t('product_name'))),
          const SizedBox(height: 8),
          TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('product_price'))),
          const SizedBox(height: 8),
          TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('product_cost'))),
          const SizedBox(height: 8),
          TextField(controller: _category, decoration: InputDecoration(labelText: t('product_category'))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t('skip'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) return;
                  int? costMinor;
                  try { costMinor = _cost.text.trim().isEmpty ? null : takaToMinor(_cost.text.trim()); } catch (_) {}
                  Navigator.pop(context, Product(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _name.text.trim(),
                    sellingPriceMinor: takaToMinor(_price.text.trim()),
                    costPriceMinor: costMinor,
                    category: _category.text.trim().isEmpty ? null : _category.text.trim(),
                  ));
                },
                child: Text(t('save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
