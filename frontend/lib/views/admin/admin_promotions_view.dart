import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';

class AdminPromotionsView extends StatefulWidget {
  const AdminPromotionsView({super.key});

  @override
  State<AdminPromotionsView> createState() => _AdminPromotionsViewState();
}

class _AdminPromotionsViewState extends State<AdminPromotionsView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _promotions = [];
  List<dynamic> _products = [];
  List<dynamic> _brands = [];
  List<dynamic> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromotions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _promotions = [
          {
            'id': 'PROM1',
            'name': 'Summer Sale 10%',
            'type': 'percentage',
            'configuration': {'percentage': 10},
            'is_active': true,
            'priority': 1,
          },
        ];
      } else {
        final responses = await Future.wait([
          _apiService.client.get('/promotions'),
          _apiService.client.get(
            '/products',
            queryParameters: {'per_page': 100},
          ),
          _apiService.client.get('/brands', queryParameters: {'per_page': 100}),
          _apiService.client.get(
            '/categories',
            queryParameters: {'per_page': 100},
          ),
        ]);
        _promotions = responses[0].data['data'] ?? [];
        _products = responses[1].data['data'] ?? [];
        _brands = responses[2].data['data'] ?? [];
        _categories = responses[3].data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading promotions: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredPromotions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _promotions;
    return _promotions.where((promotion) {
      return '${promotion['name'] ?? ''} ${promotion['type'] ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _showPromotionDialog({dynamic promotion}) async {
    final nameController = TextEditingController(
      text: promotion?['name'] ?? '',
    );
    final valueController = TextEditingController(
      text: _discountValue(promotion?['configuration']).toString(),
    );
    final priorityController = TextEditingController(
      text: (promotion?['priority'] ?? 1).toString(),
    );
    final configuration = promotion?['configuration'] as Map? ?? {};
    String type = promotion?['type'] ?? 'percentage';
    String targetScope = _targetScope(configuration);
    String? targetId = _targetId(configuration);
    bool isActive =
        promotion?['is_active'] == true || promotion?['is_active'] == 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(promotion == null ? 'New Promotion' : 'Edit Promotion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed DH')),
                    DropdownMenuItem(
                      value: 'bulk_tier',
                      child: Text('Bulk Tier'),
                    ),
                    DropdownMenuItem(
                      value: 'buy_x_get_y',
                      child: Text('Buy X Get Y'),
                    ),
                  ],
                  onChanged: (value) => setModalState(() => type = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'percentage'
                        ? 'Discount %'
                        : 'Discount Value (DH)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priorityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: targetScope,
                  decoration: InputDecoration(
                    labelText: context.tr('target_scope'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(context.tr('all')),
                    ),
                    DropdownMenuItem(
                      value: 'product',
                      child: Text(context.tr('product_specific')),
                    ),
                    DropdownMenuItem(
                      value: 'brand',
                      child: Text(context.tr('brand_specific')),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text(context.tr('category_specific')),
                    ),
                  ],
                  onChanged: (value) => setModalState(() {
                    targetScope = value ?? 'all';
                    targetId = null;
                  }),
                ),
                if (targetScope != 'all') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: targetId,
                    decoration: InputDecoration(
                      labelText: _targetLabel(targetScope),
                    ),
                    items: _targetRows(targetScope)
                        .map<DropdownMenuItem<String>>(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(
                              '${row['name'] ?? row['sku'] ?? 'Target'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setModalState(() => targetId = value),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) => setModalState(() => isActive = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
              onPressed: () async {
                final value = double.tryParse(valueController.text.trim()) ?? 0;
                final data = {
                  'name': nameController.text.trim(),
                  'type': type,
                  'configuration': _configurationFor(
                    type,
                    value,
                    targetScope,
                    targetId,
                  ),
                  'priority': int.tryParse(priorityController.text.trim()) ?? 1,
                  'is_active': isActive,
                };

                try {
                  if (!_apiService.mockMode) {
                    if (promotion == null) {
                      await _apiService.client.post('/promotions', data: data);
                    } else {
                      await _apiService.client.put(
                        '/promotions/${promotion['id']}',
                        data: data,
                      );
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Promotion save failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    valueController.dispose();
    priorityController.dispose();

    if (saved == true) {
      await _fetchPromotions();
    }
  }

  Future<void> _togglePromotion(dynamic promotion, bool enabled) async {
    try {
      final data = {
        'name': promotion['name'],
        'type': promotion['type'],
        'configuration': promotion['configuration'] ?? {},
        'priority': promotion['priority'] ?? 1,
        'is_active': enabled,
      };
      if (!_apiService.mockMode) {
        await _apiService.client.put(
          '/promotions/${promotion['id']}',
          data: data,
        );
      }
      await _fetchPromotions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update promotion: $e')));
    }
  }

  Future<void> _deletePromotion(dynamic promotion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promotion'),
        content: Text('Delete ${promotion['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (!_apiService.mockMode) {
        await _apiService.client.delete('/promotions/${promotion['id']}');
      }
      await _fetchPromotions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete promotion: $e')));
    }
  }

  Map<String, dynamic> _configurationFor(
    String type,
    double value,
    String targetScope,
    String? targetId,
  ) {
    final target = _targetConfiguration(targetScope, targetId);
    if (type == 'percentage') {
      return {'percentage': value, ...target};
    }
    if (type == 'fixed') {
      return {'amount': value, 'discount_amount': value, ...target};
    }
    if (type == 'bulk_tier') {
      return {
        ...target,
        'tiers': [
          {'min_quantity': 10, 'discount': value},
        ],
      };
    }
    return {'buy_quantity': 1, 'get_quantity': 1, 'discount': value, ...target};
  }

  Map<String, dynamic> _targetConfiguration(String scope, String? id) {
    if (scope == 'product' && id != null) {
      return {
        'product_ids': [id],
        'product_id': id,
      };
    }
    if (scope == 'brand' && id != null) {
      return {
        'brand_ids': [id],
      };
    }
    if (scope == 'category' && id != null) {
      return {
        'category_ids': [id],
      };
    }
    return {};
  }

  String _targetScope(Map configuration) {
    if ((configuration['product_ids'] as List?)?.isNotEmpty == true ||
        configuration['product_id'] != null) {
      return 'product';
    }
    if ((configuration['brand_ids'] as List?)?.isNotEmpty == true) {
      return 'brand';
    }
    if ((configuration['category_ids'] as List?)?.isNotEmpty == true) {
      return 'category';
    }
    return 'all';
  }

  String? _targetId(Map configuration) {
    final productIds = configuration['product_ids'] as List?;
    final brandIds = configuration['brand_ids'] as List?;
    final categoryIds = configuration['category_ids'] as List?;
    return (productIds?.isNotEmpty == true
            ? productIds!.first
            : configuration['product_id'] ??
                  (brandIds?.isNotEmpty == true
                      ? brandIds!.first
                      : (categoryIds?.isNotEmpty == true
                            ? categoryIds!.first
                            : null)))
        as String?;
  }

  String _targetLabel(String scope) {
    if (scope == 'product') return context.tr('products');
    if (scope == 'brand') return context.tr('brands');
    return context.tr('categories');
  }

  List<dynamic> _targetRows(String scope) {
    if (scope == 'product') return _products;
    if (scope == 'brand') return _brands;
    return _categories;
  }

  num _discountValue(dynamic configuration) {
    if (configuration is Map) {
      return configuration['percentage'] ??
          configuration['amount'] ??
          configuration['discount'] ??
          0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final promotions = _filteredPromotions;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search live promotions',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : promotions.isEmpty
                  ? const Center(child: Text('No promotions'))
                  : RefreshIndicator(
                      onRefresh: _fetchPromotions,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: promotions.length,
                        itemBuilder: (context, index) {
                          final item = promotions[index];
                          final active =
                              item['is_active'] == true ||
                              item['is_active'] == 1;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                active
                                    ? Icons.local_offer_rounded
                                    : Icons.local_offer_outlined,
                                color: active
                                    ? AppColors.secondary
                                    : AppColors.textLight,
                              ),
                              title: Text(item['name'] ?? ''),
                              subtitle: Text(
                                '${item['type']} | priority ${item['priority'] ?? 1} | value ${_discountValue(item['configuration'])}',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Switch(
                                    value: active,
                                    onChanged: (value) =>
                                        _togglePromotion(item, value),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    onPressed: () => _deletePromotion(item),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _showPromotionDialog(promotion: item),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPromotionDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Promotion'),
      ),
    );
  }
}
