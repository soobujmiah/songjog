
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/business_profile.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';
import '../../domain/models/transaction.dart';
import 'in_memory_store.dart';

class SqliteStore implements LocalStore {
  SqliteStore._(this._db);

  static const databaseName = 'songjog.db';
  static const databaseVersion = 3;

  final Database _db;

  /// Opens the durable database.
  ///
  /// [factory] is injectable so tests can run against an in-memory or file
  /// backed FFI SQLite implementation without platform channels.
  static Future<SqliteStore> open({
    String? databasePath,
    DatabaseFactory? factory,
  }) async {
    final effectiveFactory = factory ?? databaseFactory;
    final path = databasePath ??
        p.join(await effectiveFactory.getDatabasesPath(), databaseName);
    final db = await effectiveFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) => _createSchema(database),
        onUpgrade: (database, oldVersion, newVersion) =>
            _upgradeSchema(database, oldVersion, newVersion),
      ),
    );
    return SqliteStore._(db);
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE business_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        workspace_kind TEXT NOT NULL,
        business_type TEXT NOT NULL,
        subtype TEXT,
        phone TEXT,
        address TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        customer_id TEXT,
        reference TEXT,
        note TEXT,
        payment_status TEXT NOT NULL,
        payment_method TEXT,
        paid_minor INTEGER NOT NULL,
        currency_code TEXT NOT NULL DEFAULT 'BDT'
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_lines (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        selling_price_minor INTEGER NOT NULL,
        actual_cost_minor INTEGER,
        FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_transaction_lines_transaction_id '
      'ON transaction_lines(transaction_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_created_at ON transactions(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_customer_id ON transactions(customer_id)',
    );
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        selling_price_minor INTEGER NOT NULL,
        cost_price_minor INTEGER,
        category TEXT
      )
    ''');
  }

  static Future<void> _upgradeSchema(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'BDT'",
      );
      await db.execute(
        'CREATE INDEX idx_transactions_customer_id ON transactions(customer_id)',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          selling_price_minor INTEGER NOT NULL,
          cost_price_minor INTEGER,
          category TEXT
        )
      ''');
    }
  }

  @override
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    await _db.insert(
      'business_profile',
      {
        'id': profile.id,
        'name': profile.name,
        'workspace_kind': profile.workspaceKind.name,
        'business_type': profile.businessType.name,
        'subtype': profile.subtype,
        'phone': profile.phone,
        'address': profile.address,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<BusinessProfile?> loadBusinessProfile() async {
    final rows = await _db.query('business_profile', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return BusinessProfile(
      id: row['id']! as String,
      name: row['name']! as String,
      workspaceKind: WorkspaceKind.values.byName(row['workspace_kind']! as String),
      businessType: BusinessType.values.byName(row['business_type']! as String),
      subtype: row['subtype'] as String?,
      phone: row['phone'] as String?,
      address: row['address'] as String?,
    );
  }

  @override
  Future<void> saveTransaction(TransactionRecord transaction) async {
    if (transaction.lines.isEmpty) {
      throw ArgumentError('A transaction must contain at least one line.');
    }
    await _db.transaction((txn) async {
      await txn.insert(
        'transactions',
        {
          'id': transaction.id,
          'type': transaction.type.name,
          'created_at': transaction.createdAt.millisecondsSinceEpoch,
          'customer_id': transaction.customerId,
          'reference': transaction.reference,
          'note': transaction.note,
          'payment_status': transaction.paymentStatus.name,
          'payment_method': transaction.paymentMethod?.name,
          'paid_minor': transaction.paidMinor,
          'currency_code': 'BDT',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [transaction.id],
      );
      for (final line in transaction.lines) {
        await txn.insert('transaction_lines', {
          'id': line.id,
          'transaction_id': transaction.id,
          'description': line.description,
          'quantity': line.quantity,
          'selling_price_minor': line.sellingPriceMinor,
          'actual_cost_minor': line.actualCostMinor,
        });
      }
    });
  }

  @override
  Future<List<TransactionRecord>> loadTransactions() async {
    final rows = await _db.query('transactions', orderBy: 'created_at DESC');
    final result = <TransactionRecord>[];
    for (final row in rows) {
      final lineRows = await _db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [row['id']],
      );
      result.add(TransactionRecord(
        id: row['id']! as String,
        type: TransactionType.values.byName(row['type']! as String),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        customerId: row['customer_id'] as String?,
        reference: row['reference'] as String?,
        note: row['note'] as String?,
        paymentStatus: PaymentStatus.values.byName(row['payment_status']! as String),
        paymentMethod: row['payment_method'] == null
            ? null
            : PaymentMethod.values.byName(row['payment_method']! as String),
        paidMinor: row['paid_minor']! as int,
        lines: lineRows.map((line) => TransactionLine(
          id: line['id']! as String,
          description: line['description']! as String,
          quantity: (line['quantity']! as num).toDouble(),
          sellingPriceMinor: line['selling_price_minor']! as int,
          actualCostMinor: line['actual_cost_minor'] as int?,
        )).toList(),
      ));
    }
    return result;
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    await _db.insert(
      'customers',
      {'id': customer.id, 'name': customer.name, 'phone': customer.phone},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Customer>> getCustomers() async {
    final rows = await _db.query('customers', orderBy: 'name ASC');
    return rows
        .map((r) => Customer(
              id: r['id']! as String,
              name: r['name']! as String,
              phone: r['phone'] as String?,
            ))
        .toList();
  }

  @override
  Future<Customer?> getCustomer(String id) async {
    final rows = await _db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Customer(
      id: r['id']! as String,
      name: r['name']! as String,
      phone: r['phone'] as String?,
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    await _db.insert(
      'products',
      {
        'id': product.id,
        'name': product.name,
        'selling_price_minor': product.sellingPriceMinor,
        'cost_price_minor': product.costPriceMinor,
        'category': product.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _db.query('products', orderBy: 'name ASC');
    return rows
        .map((r) => Product(
              id: r['id']! as String,
              name: r['name']! as String,
              sellingPriceMinor: r['selling_price_minor']! as int,
              costPriceMinor: r['cost_price_minor'] as int?,
              category: r['category'] as String?,
            ))
        .toList();
  }

  @override
  Future<Product?> getProduct(String id) async {
    final rows = await _db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Product(
      id: r['id']! as String,
      name: r['name']! as String,
      sellingPriceMinor: r['selling_price_minor']! as int,
      costPriceMinor: r['cost_price_minor'] as int?,
      category: r['category'] as String?,
    );
  }

  @override
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    List<Map<String, dynamic>> txRows;
    if (from != null && to != null) {
      txRows = await _db.query(
        'transactions',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        orderBy: 'created_at DESC',
      );
    } else if (from != null) {
      txRows = await _db.query(
        'transactions',
        where: 'created_at >= ?',
        whereArgs: [from.millisecondsSinceEpoch],
        orderBy: 'created_at DESC',
      );
    } else if (to != null) {
      txRows = await _db.query(
        'transactions',
        where: 'created_at <= ?',
        whereArgs: [to.millisecondsSinceEpoch],
        orderBy: 'created_at DESC',
      );
    } else {
      txRows = await _db.query('transactions', orderBy: 'created_at DESC');
    }

    int salesTotal = 0;
    int grossProfit = 0;
    int expenseTotal = 0;
    int outstandingDues = 0;

    for (final row in txRows) {
      final type = row['type'] as String;
      final paidMinor = row['paid_minor'] as int;
      final paymentStatus = row['payment_status'] as String;

      final lineRows = await _db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [row['id']],
      );
      final lineTotal = lineRows.fold<int>(
        0,
        (s, l) => s + ((l['selling_price_minor']! as int) * (l['quantity']! as num).toDouble()).round(),
      );
      final lineCost = lineRows.fold<int?>(
        0,
        (acc, l) {
          final cost = l['actual_cost_minor'] as int?;
          if (cost == null) return null;
          return acc! + (cost * (l['quantity']! as num).toDouble()).round();
        },
      );

      if (type == 'sale' || type == 'serviceSale') {
        salesTotal += lineTotal;
        if (lineCost != null) grossProfit += lineTotal - lineCost;
      } else if (type == 'expense') {
        expenseTotal += lineTotal;
      }

      if (paymentStatus == 'unpaid' || paymentStatus == 'partial') {
        outstandingDues += lineTotal - paidMinor;
      }
    }

    return {
      'sales': salesTotal,
      'grossProfit': grossProfit,
      'expenses': expenseTotal,
      'outstandingDues': outstandingDues,
    };
  }

  Future<void> close() => _db.close();
}
