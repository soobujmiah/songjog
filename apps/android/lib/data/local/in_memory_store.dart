import '../../domain/models/business_profile.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';
import '../../domain/models/transaction.dart';

/// Small persistence boundary used by the first application layer.
///
/// The interface deliberately hides storage details from the domain. A durable
/// database implementation can replace this store without changing domain
/// models or presentation code.
abstract interface class LocalStore {
  Future<void> saveBusinessProfile(BusinessProfile profile);
  Future<BusinessProfile?> loadBusinessProfile();
  Future<void> saveTransaction(TransactionRecord transaction);
  Future<List<TransactionRecord>> loadTransactions();
  // Customers & products (v3+)
  Future<void> saveCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
  Future<List<Customer>> getCustomers();
  Future<Customer?> getCustomer(String id);
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<List<Product>> getProducts();
  Future<Product?> getProduct(String id);
  // Financial summary
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? from,
    DateTime? to,
  });
}

class InMemoryStore implements LocalStore {
  BusinessProfile? _profile;
  final List<TransactionRecord> _transactions = <TransactionRecord>[];
  final List<Customer> _customers = <Customer>[];
  final List<Product> _products = <Product>[];

  @override
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    _profile = profile;
  }

  @override
  Future<BusinessProfile?> loadBusinessProfile() async => _profile;

  @override
  Future<void> saveTransaction(TransactionRecord transaction) async {
    _transactions.removeWhere((item) => item.id == transaction.id);
    _transactions.add(transaction);
  }

  @override
  Future<List<TransactionRecord>> loadTransactions() async =>
      List.unmodifiable(_transactions);

  @override
  Future<void> saveCustomer(Customer customer) async {
    _customers.removeWhere((c) => c.id == customer.id);
    _customers.add(customer);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Customer>> getCustomers() async => List.unmodifiable(_customers);

  @override
  Future<Customer?> getCustomer(String id) async {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProduct(Product product) async {
    _products.removeWhere((p) => p.id == product.id);
    _products.add(product);
  }

  @override
  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Product>> getProducts() async => List.unmodifiable(_products);

  @override
  Future<Product?> getProduct(String id) async {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    var transactions = _transactions;
    if (from != null) {
      transactions = transactions
          .where((t) => t.createdAt.isAfter(from.subtract(const Duration(days: 1))))
          .toList();
    }
    if (to != null) {
      transactions = transactions
          .where((t) => t.createdAt.isBefore(to.add(const Duration(days: 1))))
          .toList();
    }

    final salesLines = transactions
        .where((t) =>
            t.type == TransactionType.sale ||
            t.type == TransactionType.serviceSale)
        .fold(
      {'total': 0, 'grossProfit': 0},
      (acc, t) => {
        'total': acc['total']! + t.totalMinor,
        'grossProfit': acc['grossProfit']! + t.grossProfitMinor,
      },
    );

    final expenseTotal = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.totalMinor);

    final outstandingDues = transactions
        .where((t) => t.paymentStatus == PaymentStatus.unpaid ||
            t.paymentStatus == PaymentStatus.partial)
        .fold<int>(0, (sum, t) => sum + t.dueMinor);

    return {
      'sales': salesLines['total'],
      'grossProfit': salesLines['grossProfit'],
      'expenses': expenseTotal,
      'outstandingDues': outstandingDues,
    };
  }
}
