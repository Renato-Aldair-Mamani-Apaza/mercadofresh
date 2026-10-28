// lib/core/di/injection_container.dart
import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1. Base de datos
  sl.registerSingleton<AppDatabase>(AppDatabase());
  sl.registerSingleton<ProductsDao>(sl<AppDatabase>().productsDao);
  sl.registerSingleton<SalesDao>(sl<AppDatabase>().salesDao);

  // 2. Repositorio principal (implementa ambas interfaces)
  final repositoryImpl = ProductRepositoryImpl(sl<AppDatabase>());

  sl.registerLazySingleton<ProductRepository>(() => repositoryImpl);
  sl.registerLazySingleton<SaleRepository>(() => repositoryImpl);
}