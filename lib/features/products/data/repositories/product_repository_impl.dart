// lib/features/products/data/repositories/product_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository, SaleRepository {
  final AppDatabase database;

  ProductRepositoryImpl(this.database);

  // ── ProductRepository ─────────────────────────────────

  @override
  Stream<List<ProductEntity>> watchAllProducts() {
    return database.select(database.products).watch().map((rows) {
      return rows.map((row) => _mapToProductEntity(row)).toList();
    });
  }

  @override
  Stream<List<ProductEntity>> watchActiveProducts() {
    return (database.select(database.products)
          ..where((tbl) => tbl.isActive.equals(true)))
        .watch()
        .map((rows) {
      return rows.map((row) => _mapToProductEntity(row)).toList();
    });
  }

  @override
  Future<Either<Failure, ProductEntity>> addProduct({
    required String name,
    required String category,
    required double price,
    required double stock,
    required String unit,
  }) async {
    try {
      final companion = ProductsCompanion.insert(
        name: name,
        category: category,
        price: price,
        stock: Value(stock),
        unit: Value(unit),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final id = await database.into(database.products).insert(companion);
      final inserted = await (database.select(database.products)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingle();

      return Right(_mapToProductEntity(inserted));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(
    int id, {
    String? name,
    String? category,
    double? price,
    double? stock,
    String? unit,
  }) async {
    try {
      final companion = ProductsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        price: price != null ? Value(price) : const Value.absent(),
        stock: stock != null ? Value(stock) : const Value.absent(),
        unit: unit != null ? Value(unit) : const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      );

      await (database.update(database.products)
            ..where((tbl) => tbl.id.equals(id)))
          .write(companion);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(int id) async {
    try {
      await (database.delete(database.products)
            ..where((tbl) => tbl.id.equals(id)))
          .go();
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // ── SaleRepository ────────────────────────────────────

  @override
  Stream<List<SaleEntity>> watchAllSales() {
    return database.select(database.sales).watch().map((rows) {
      return rows.map((row) => _mapToSaleEntity(row)).toList();
    });
  }

  @override
  Future<Either<Failure, SaleEntity>> registerSale({
    required int productId,
    required double quantity,
    required double unitPrice,
    String? buyerName,
  }) async {
    try {
      return await database.transaction(() async {
        final product = await (database.select(database.products)
              ..where((tbl) => tbl.id.equals(productId)))
            .getSingle();

        if (product.stock < quantity) {
          return Left(DatabaseFailure('Stock insuficiente'));
        }

        final newStock = product.stock - quantity;
        await (database.update(database.products)
              ..where((tbl) => tbl.id.equals(productId)))
            .write(ProductsCompanion(
              stock: Value(newStock),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ));

        final totalAmount = quantity * unitPrice;
        final saleCompanion = SalesCompanion.insert(
          productId: productId,
          quantity: quantity,
          unitPrice: unitPrice,
          total: totalAmount,
          saleDate: DateTime.now().millisecondsSinceEpoch,
          buyerName: Value(buyerName),
        );

        final saleId = await database.into(database.sales).insert(saleCompanion);
        final insertedSale = await (database.select(database.sales)
              ..where((tbl) => tbl.id.equals(saleId)))
            .getSingle();

        return Right(_mapToSaleEntity(insertedSale));
      });
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalRevenue() async {
    try {
      final sales = await database.select(database.sales).get();
      final total = sales.fold<double>(0.0, (sum, sale) => sum + sale.total);
      return Right(total);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // ── Mappers ───────────────────────────────────────────

  ProductEntity _mapToProductEntity(Product row) {
    return ProductEntity(
      id: row.id,
      name: row.name,
      category: row.category,
      price: row.price,
      stock: row.stock,
      unit: row.unit,
      isActive: row.isActive,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  SaleEntity _mapToSaleEntity(Sale row) {
    return SaleEntity(
      id: row.id,
      productId: row.productId,
      quantity: row.quantity,
      unitPrice: row.unitPrice,
      total: row.total,
      buyerName: row.buyerName,
      saleDate: DateTime.fromMillisecondsSinceEpoch(row.saleDate),
    );
  }
}