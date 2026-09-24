class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sellingPriceMinor,
    this.costPriceMinor,
    this.category,
  });

  final String id;
  final String name;
  final int sellingPriceMinor;
  final int? costPriceMinor;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.sellingPriceMinor == sellingPriceMinor &&
      other.costPriceMinor == costPriceMinor &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(id, name, sellingPriceMinor, costPriceMinor, category);
}
