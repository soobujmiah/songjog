import '../../domain/models/business_profile.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';
import '../../domain/models/transaction.dart';
import '../local/in_memory_store.dart';

abstract interface class BusinessRepository {
  Future<void> saveProfile(BusinessProfile profile);
  Future<BusinessProfile?> getProfile();
  Future<void> saveTransaction(TransactionRecord transaction);
  Future<List<TransactionRecord>> getTransactions();
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
  // Customer open balance
  Future<int> getCustomerOpenBalance(String customerId);
}

class DefaultBusinessRepository implements BusinessRepository {
  const DefaultBusinessRepository(this._store);

  final LocalStore _store;

  @override
  Future<void> saveProfile(BusinessProfile profile) =>
      _store.saveBusinessProfile(profile);

  @override
  Future<BusinessProfile?> getProfile() => _store.loadBusinessProfile();

  @override
  Future<void> saveTransaction(TransactionRecord transaction) =>
      _store.saveTransaction(transaction);

  @override
  Future<List<TransactionRecord>> getTransactions() =>
      _store.loadTransactions();

  @override
  Future<void> saveCustomer(Customer customer) => _store.saveCustomer(customer);

  @override
  Future<void> deleteCustomer(String id) => _store.deleteCustomer(id);

  @override
  Future<List<Customer>> getCustomers() => _store.getCustomers();

  @override
  Future<Customer?> getCustomer(String id) => _store.getCustomer(id);

  @override
  Future<void> saveProduct(Product product) => _store.saveProduct(product);

  @override
  Future<void> deleteProduct(String id) => _store.deleteProduct(id);

  @override
  Future<List<Product>> getProducts() => _store.getProducts();

  @override
  Future<Product?> getProduct(String id) => _store.getProduct(id);

  @override
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? from,
    DateTime? to,
  }) =>
      _store.getFinancialSummary(from: from, to: to);

  @override
  Future<int> getCustomerOpenBalance(String customerId) async {
    final transactions = await _store.loadTransactions();
    int balance = 0;
    for (final tx in transactions) {
      if (tx.customerId == customerId) {
        if (tx.type == TransactionType.sale || tx.type == TransactionType.serviceSale) {
          balance += tx.dueMinor;
        } else if (tx.type == TransactionType.paymentReceived) {
          balance -= tx.paidMinor;
        }
      }
    }
    return balance < 0 ? 0 : balance;
  }
}
