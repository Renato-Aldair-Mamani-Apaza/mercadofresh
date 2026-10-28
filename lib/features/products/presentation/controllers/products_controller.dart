// lib/features/products/presentation/controllers/products_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../../../core/di/injection_container.dart';

// ── Filtro por categoría ───────────────────────────────
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ── Productos filtrados ────────────────────────────────
final filteredProductsProvider = Provider<AsyncValue<List<ProductEntity>>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return productsAsync.whenData((products) {
    if (selectedCategory == null || selectedCategory.isEmpty) {
      return products;
    }
    return products
        .where((p) => p.category.toLowerCase() == selectedCategory.toLowerCase())
        .toList();
  });
});

// ── Streams ───────────────────────────────────────────
final productsStreamProvider = StreamProvider<List<ProductEntity>>((ref) {
  return sl<ProductRepository>().watchAllProducts();
});

final salesStreamProvider = StreamProvider<List<SaleEntity>>((ref) {
  return sl<SaleRepository>().watchAllSales();
});

// ── Ingreso total del día ──────────────────────────────
final totalRevenueProvider = FutureProvider<double>((ref) async {
  final result = await sl<SaleRepository>().getTotalRevenue();
  return result.fold(
    (failure) => 0.0,
    (total) => total,
  );
});

// ── Controller CRUD ───────────────────────────────────
class ProductsController extends AsyncNotifier<List<ProductEntity>> {
  @override
  Future<List<ProductEntity>> build() async {
    return await sl<ProductRepository>().watchAllProducts().first;
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required double price,
    required double stock,
    required String unit,
  }) async {
    final result = await sl<ProductRepository>().addProduct(
      name: name,
      category: category,
      price: price,
      stock: stock,
      unit: unit,
    );

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        ref.invalidate(productsStreamProvider);
        refresh();
      },
    );
  }

  Future<void> deleteProduct(int id) async {
    final result = await sl<ProductRepository>().deleteProduct(id);

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        ref.invalidate(productsStreamProvider);
        refresh();
      },
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => sl<ProductRepository>().watchAllProducts().first);
  }
}

final productsControllerProvider =
    AsyncNotifierProvider<ProductsController, List<ProductEntity>>(
  ProductsController.new,
);

// ── Controller de ventas ──────────────────────────────
class SalesController extends AsyncNotifier<List<SaleEntity>> {
  @override
  Future<List<SaleEntity>> build() async {
    return await sl<SaleRepository>().watchAllSales().first;
  }

  Future<void> registerSale({
    required int productId,
    required double quantity,
    required double unitPrice,
    String? buyer,
  }) async {
    final result = await sl<SaleRepository>().registerSale(
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      buyerName: buyer,
    );

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        // Refrescar proveedores para sincronizar stock e ingresos en vivo
        ref.invalidate(totalRevenueProvider);
        ref.invalidate(productsStreamProvider);
        ref.invalidate(salesStreamProvider);
        refresh();
      },
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => sl<SaleRepository>().watchAllSales().first);
  }
}

final salesControllerProvider =
    AsyncNotifierProvider<SalesController, List<SaleEntity>>(
  SalesController.new,
);