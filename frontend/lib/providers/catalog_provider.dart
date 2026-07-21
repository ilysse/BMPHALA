import 'package:flutter/material.dart';
import '../models/product.dart';
import '../core/network/api_service.dart';

class CatalogProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<CatalogFacet> _categories = const [CatalogFacet(id: 'all', name: 'All')];
  List<CatalogFacet> _brands = const [CatalogFacet(id: 'all', name: 'All')];
  String _selectedCategoryId = 'all';
  String _selectedBrandId = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Product> get products {
    return _products.where((product) {
      final matchesCategory =
          _selectedCategoryId == 'all' ||
          product.categoryId == _selectedCategoryId ||
          product.category == _selectedCategoryId;
      final matchesBrand =
          _selectedBrandId == 'all' || product.brandId == _selectedBrandId;
      final matchesSearch =
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesBrand && matchesSearch;
    }).toList();
  }

  List<Product> get rawProducts => _products;
  List<CatalogFacet> get categories => _categories;
  List<CatalogFacet> get brands => _brands;
  String get selectedCategoryId => _selectedCategoryId;
  String get selectedBrandId => _selectedBrandId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _products = _getMockProducts();
        final categoryNames = _products
            .map((product) => product.category)
            .toSet();
        _categories = [
          const CatalogFacet(id: 'all', name: 'All'),
          ...categoryNames.map((name) => CatalogFacet(id: name, name: name)),
        ];
      } else {
        final responses = await Future.wait([
          _apiService.client.get(
            '/products',
            queryParameters: {'per_page': 100},
          ),
          _apiService.client.get(
            '/categories',
            queryParameters: {'per_page': 100},
          ),
          _apiService.client.get('/brands', queryParameters: {'per_page': 100}),
        ]);
        final response = responses[0];
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;
          _products = data
              .map((json) => Product.fromJson(json as Map<String, dynamic>))
              .toList();
        }

        final catResponse = responses[1];
        if (catResponse.statusCode == 200) {
          final List<dynamic> catData =
              catResponse.data['data'] as List<dynamic>;
          _categories = [
            const CatalogFacet(id: 'all', name: 'All'),
            ...catData.map(
              (c) => CatalogFacet(
                id: c['id'] as String,
                name: c['name'] as String? ?? '',
                imageUrl: c['image_url'] as String?,
              ),
            ),
          ];
        }

        final brandResponse = responses[2];
        if (brandResponse.statusCode == 200) {
          final List<dynamic> brandData =
              brandResponse.data['data'] as List<dynamic>;
          _brands = [
            const CatalogFacet(id: 'all', name: 'All'),
            ...brandData.map(
              (b) => CatalogFacet(
                id: b['id'] as String,
                name: b['name'] as String? ?? '',
                imageUrl: b['logo_url'] as String?,
              ),
            ),
          ];
        }
      }
    } catch (e) {
      _error = 'Failed to load catalog products: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setBrand(String brandId) {
    _selectedBrandId = brandId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateProductStock(String productId, int quantityChange) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      _products[index] = product.copyWith(
        stock: (product.stock + quantityChange).clamp(0, 9999),
      );
      notifyListeners();
    }
  }

  List<Product> _getMockProducts() {
    return [
      Product(
        id: 'PROD_001',
        name: 'Premium Roasted Coffee Beans',
        sku: 'BEV-COF-001',
        price: 18.50,
        category: 'Beverages',
        stock: 45,
        imageUrl:
            'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500&q=80',
        description:
            '100% Arabica medium roast coffee beans sourced from single-origin farms in East Africa. Features rich chocolate and citrus tasting notes.',
      ),
      Product(
        id: 'PROD_002',
        name: 'Organic Green Tea (50 Bags)',
        sku: 'BEV-TEA-002',
        price: 9.99,
        category: 'Beverages',
        stock: 120,
        imageUrl:
            'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?w=500&q=80',
        description:
            'Antioxidant-rich organic green tea leaves packed in eco-friendly biodegradable pyramid tea bags for optimal brewing and flavor extraction.',
      ),
      Product(
        id: 'PROD_003',
        name: 'Gourmet Sea Salt Potato Chips',
        sku: 'SNA-CHP-003',
        price: 3.49,
        category: 'Snacks',
        stock: 250,
        imageUrl:
            'https://images.unsplash.com/photo-1566478989037-eec170784d20?w=500&q=80',
        description:
            'Kettle-cooked golden potato chips seasoned with natural hand-harvested sea salt. Crispy, gluten-free, and perfect for snacking.',
      ),
      Product(
        id: 'PROD_004',
        name: 'Roasted Salted Almonds (500g)',
        sku: 'SNA-NUT-004',
        price: 12.99,
        category: 'Snacks',
        stock: 85,
        imageUrl:
            'https://images.unsplash.com/photo-1508061253366-f7da158b6d4f?w=500&q=80',
        description:
            'Premium whole almonds, slow-roasted and lightly sprinkled with sea salt. Rich in healthy fats, fiber, and protein.',
      ),
      Product(
        id: 'PROD_005',
        name: 'Basmati Rice Extra Long Grain (5kg)',
        sku: 'GRN-RIC-005',
        price: 15.99,
        category: 'Grains & Pasta',
        stock: 60,
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500&q=80',
        description:
            'Aromatic, aged extra-long grain Basmati rice. Perfect for biryanis, pilafs, or as a fluffy side dish for curries and stews.',
      ),
      Product(
        id: 'PROD_006',
        name: 'Organic Whole Wheat Penne (1kg)',
        sku: 'GRN-PST-006',
        price: 4.25,
        category: 'Grains & Pasta',
        stock: 140,
        imageUrl:
            'https://images.unsplash.com/photo-1621961404018-81990fec2bc9?w=500&q=80',
        description:
            'Italian whole wheat penne pasta, bronze-cut for a rough texture that holds sauces perfectly. High in fiber and organic certified.',
      ),
      Product(
        id: 'PROD_007',
        name: 'Extra Virgin Olive Oil (1L)',
        sku: 'PKG-OIL-007',
        price: 22.00,
        category: 'Packaged Foods',
        stock: 40,
        imageUrl:
            'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500&q=80',
        description:
            'Cold-pressed extra virgin olive oil from Spanish olives. Offers a smooth, fruity flavor profile with a subtle peppery finish.',
      ),
      Product(
        id: 'PROD_008',
        name: 'Natural Blossom Honey (450g)',
        sku: 'PKG-HON-008',
        price: 8.75,
        category: 'Packaged Foods',
        stock: 95,
        imageUrl:
            'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=500&q=80',
        description:
            'Pure, raw wildflower honey collected from sustainable apiaries. Unfiltered and unpasteurized to preserve natural enzymes and pollen.',
      ),
      Product(
        id: 'PROD_009',
        name: 'Herbal Moisturizing Body Wash',
        sku: 'HYG-WSH-009',
        price: 7.99,
        category: 'Hygiene',
        stock: 110,
        imageUrl:
            'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?w=500&q=80',
        description:
            'Gentle, pH-balanced body wash infused with aloe vera, chamomile, and essential lavender oils to soothe and hydrate sensitive skin.',
      ),
    ];
  }
}

class CatalogFacet {
  final String id;
  final String name;
  final String? imageUrl;

  const CatalogFacet({required this.id, required this.name, this.imageUrl});
}
