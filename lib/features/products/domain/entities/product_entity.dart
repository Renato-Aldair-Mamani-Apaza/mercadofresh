// lib/features/products/domain/entities/product_entity.dart
//
// ⚠️  IMPLEMENTACIÓN INCOMPLETA — completar los métodos marcados con // TODO
//
import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final int id;
  final String name;
  final String category;
  final double price;
  final double stock;
  final String unit;
  final bool isActive;
  final DateTime updatedAt;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.unit,
    required this.isActive,
    required this.updatedAt,
  });

  bool get isLowStock => stock <= 5.0;

  String get stockLabel => '$stock $unit';

  String get formattedPrice => 'S/ ${price.toStringAsFixed(2)}';

  String get categoryDisplay {
    switch (category.toUpperCase()) {
      case 'VERDURAS':
        return '🥦 VERDURAS';
      case 'FRUTAS':
        return '🍎 FRUTAS';
      case 'CARNES':
        return '🥩 CARNES';
      default:
        return '📦 $category';
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        price,
        stock,
        unit,
        isActive,
        updatedAt,
      ];
}

class SaleEntity extends Equatable {
  final int id;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? buyerName;
  final DateTime saleDate;

  const SaleEntity({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.buyerName,
    required this.saleDate,
  });

  bool get isLargeSale => total > 100.0;

  String get formattedTotal => 'S/ ${total.toStringAsFixed(2)}';

  @override
  List<Object?> get props => [
        id,
        productId,
        quantity,
        unitPrice,
        total,
        buyerName,
        saleDate,
      ];
}