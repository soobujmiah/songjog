import 'package:flutter_test/flutter_test.dart';
import 'package:songjog/domain/models/product.dart';

void main() {
  group('Product', () {
    test('constructor requires selling price', () {
      final p = const Product(id: 'p1', name: 'Mouse', sellingPriceMinor: 55000);
      expect(p.sellingPriceMinor, 55000);
      expect(p.costPriceMinor, isNull);
      expect(p.category, isNull);
    });

    test('optional fields default to null', () {
      final p = const Product(id: 'p2', name: 'Keyboard', sellingPriceMinor: 12000);
      expect(p.costPriceMinor, isNull);
      expect(p.category, isNull);
    });

    test('full constructor stores cost and category', () {
      final p = const Product(
        id: 'p3',
        name: 'Monitor',
        sellingPriceMinor: 85000,
        costPriceMinor: 70000,
        category: 'Electronics',
      );
      expect(p.costPriceMinor, 70000);
      expect(p.category, 'Electronics');
    });

    test('equality matches on all fields', () {
      final a = const Product(id: 'p1', name: 'Mouse', sellingPriceMinor: 55000);
      final b = const Product(id: 'p1', name: 'Mouse', sellingPriceMinor: 55000);
      final c = const Product(id: 'p1', name: 'Mouse', sellingPriceMinor: 55000, costPriceMinor: 40000);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('different ids are never equal', () {
      final a = const Product(id: 'p1', name: 'Mouse', sellingPriceMinor: 55000);
      final b = const Product(id: 'p2', name: 'Mouse', sellingPriceMinor: 55000);
      expect(a == b, isFalse);
    });
  });
}
