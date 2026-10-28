import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../errors/failures.dart';

part 'app_database.g.dart';

// TABLA: products
class Products extends Table {
  IntColumn  get id        => integer().autoIncrement()();
  TextColumn get name      => text().withLength(min: 1, max: 150)();
  TextColumn get category  => text()();
  RealColumn get price     => real()();
  RealColumn get stock     => real().withDefault(const Constant(0.0))();
  TextColumn get unit      => text().withDefault(const Constant('kg'))();
  BoolColumn get isActive  => boolean().withDefault(const Constant(true))();
  IntColumn  get updatedAt => integer().named('updated_at')();
}

// TABLA: sales
class Sales extends Table {
  IntColumn  get id        => integer().autoIncrement()();
  IntColumn  get productId => integer().named('product_id').references(Products, #id)();
  RealColumn get quantity  => real()();
  RealColumn get unitPrice => real().named('unit_price')();
  RealColumn get total     => real()();
  TextColumn get buyerName => text().named('buyer_name').nullable()();
  IntColumn  get saleDate  => integer().named('sale_date')();
}

// DAO: ProductsDao
@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase> with _$ProductsDaoMixin {
  ProductsDao(super.db);

  Future<List<Product>> getAllProducts() => select(products).get();
  Stream<List<Product>> watchAllProducts() => select(products).watch();

  Stream<List<Product>> watchActiveProducts() =>
      (select(products)..where((p) => p.isActive.equals(true))).watch();

  Future<List<Product>> getByCategory(String category) {
    return (select(products)..where((p) => p.category.equals(category))).get();
  }

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  Future<bool> updateProduct(int id, ProductsCompanion data) async {
    final rows = await (update(products)..where((p) => p.id.equals(id))).write(data);
    return rows > 0;
  }

  Future<void> decrementStock(int productId, double quantity) async {
    final product = await (select(products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    
    if (product.stock < quantity) {
      throw Exception('Stock insuficiente');
    }

    await (update(products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stock: Value(product.stock - quantity)));
  }

  Future<int> deleteProduct(int id) {
    return (delete(products)..where((p) => p.id.equals(id))).go();
  }
}

// DAO: SalesDao
@DriftAccessor(tables: [Sales])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  Stream<List<Sale>> watchAllSales() => select(sales).watch();

  Future<List<Sale>> getSalesByProduct(int productId) =>
      (select(sales)..where((s) => s.productId.equals(productId))).get();

  Future<List<Sale>> getTodaySales() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return (select(sales)..where((s) => s.saleDate.isBiggerOrEqualValue(startOfDay))).get();
  }

  Future<int> insertSale(SalesCompanion sale) =>
      into(sales).insert(sale);

  Future<double> getTotalRevenue() async {
    final allSales = await select(sales).get();
    return allSales.fold<double>(0.0, (sum, sale) => sum + sale.total);
  }
}

// AppDatabase
@DriftDatabase(
  tables: [Products, Sales],
  daos:   [ProductsDao, SalesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('PRAGMA journal_mode=WAL');
      await customStatement('PRAGMA foreign_keys=ON');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'mercadofresh.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}