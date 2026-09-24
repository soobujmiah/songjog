import 'package:flutter_test/flutter_test.dart';
import 'package:songjog/domain/models/customer.dart';

void main() {
  group('Customer', () {
    test('constructor enforces required fields', () {
      final c = const Customer(id: 'c1', name: 'Rahim');
      expect(c.id, 'c1');
      expect(c.name, 'Rahim');
      expect(c.phone, isNull);
    });

    test('optional phone stores correctly', () {
      final c = const Customer(id: 'c2', name: 'Karim', phone: '01700000000');
      expect(c.phone, '01700000000');
    });

    test('equality matches on all fields', () {
      final a = const Customer(id: 'c1', name: 'Rahim', phone: '01700000000');
      final b = const Customer(id: 'c1', name: 'Rahim', phone: '01700000000');
      final c = const Customer(id: 'c1', name: 'Rahim', phone: null);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hash code is consistent with equality', () {
      final a = const Customer(id: 'c1', name: 'Rahim', phone: '01700000000');
      final b = const Customer(id: 'c1', name: 'Rahim', phone: '01700000000');
      expect(a.hashCode, b.hashCode);
    });
  });
}
