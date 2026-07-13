class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final String category;
  final int stock;
  final String imageUrl;
  final String description;
  final double? costPrice;
  final int packSize;
  final String packUnit;
  final bool isActive;
  final String? categoryId;
  final String? brandId;
  final String brand;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.category,
    required this.stock,
    required this.imageUrl,
    required this.description,
    this.costPrice,
    this.packSize = 1,
    this.packUnit = 'pcs',
    this.isActive = true,
    this.categoryId,
    this.brandId,
    this.brand = 'Unbranded',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Safely extract category name if category object exists
    String categoryName = 'Uncategorized';
    if (json['category'] != null && json['category'] is Map) {
      categoryName = (json['category']['name'] ?? 'Uncategorized') as String;
    } else if (json['category_id'] != null) {
      categoryName = json['category_id'].toString();
    }

    String brandName = 'Unbranded';
    if (json['brand'] is Map) {
      brandName = (json['brand']['name'] ?? 'Unbranded') as String;
    }

    return Product(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      price: _toDouble(json['price']),
      category: categoryName,
      stock: _toInt(json['stock'] ?? json['quantity']),
      imageUrl:
          (json['image_url'] == null || (json['image_url'] as String).isEmpty)
          ? (json['imageUrl'] == null || (json['imageUrl'] as String).isEmpty
                ? 'https://placehold.co/150x150/png'
                : json['imageUrl'] as String)
          : json['image_url'] as String,
      description: (json['description'] ?? '') as String,
      costPrice: json['cost_price'] == null
          ? null
          : _toDouble(json['cost_price']),
      packSize: json['pack_size'] as int? ?? 1,
      packUnit: (json['pack_unit'] ?? 'pcs') as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      categoryId: json['category_id'] as String?,
      brandId: json['brand_id'] as String?,
      brand: brandName,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'category': category,
      'stock': stock,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'description': description,
      'cost_price': costPrice,
      'pack_size': packSize,
      'pack_unit': packUnit,
      'is_active': isActive,
      'category_id': categoryId,
      'brand_id': brandId,
      'brand': brand,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    String? category,
    int? stock,
    String? imageUrl,
    String? description,
    double? costPrice,
    int? packSize,
    String? packUnit,
    bool? isActive,
    String? categoryId,
    String? brandId,
    String? brand,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      costPrice: costPrice ?? this.costPrice,
      packSize: packSize ?? this.packSize,
      packUnit: packUnit ?? this.packUnit,
      isActive: isActive ?? this.isActive,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      brand: brand ?? this.brand,
    );
  }
}
