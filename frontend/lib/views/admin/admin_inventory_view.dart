import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';

class AdminInventoryView extends StatefulWidget {
  const AdminInventoryView({super.key});

  @override
  State<AdminInventoryView> createState() => _AdminInventoryViewState();
}

class _AdminInventoryViewState extends State<AdminInventoryView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _inventory = [];
  List<dynamic> _products = [];
  List<dynamic> _warehouses = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) _fetchData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _warehouses = [
          {'id': 'WH1', 'name': 'Main Warehouse', 'location': 'HQ'},
        ];
        _products = [
          {'id': 'PR1', 'name': 'Evian Water 500ml', 'sku': 'EV-500'},
        ];
        _inventory = [
          {
            'id': 'INV1',
            'product_id': 'PR1',
            'warehouse_id': 'WH1',
            'product': {'name': 'Evian Water 500ml', 'sku': 'EV-500'},
            'warehouse': {'name': 'Main Warehouse'},
            'quantity': 150,
            'min_stock': 50,
            'max_stock': 1000,
          },
        ];
      } else {
        final responses = await Future.wait([
          _apiService.client.get(
            '/inventory',
            queryParameters: {'per_page': 100},
          ),
          _apiService.client.get(
            '/products',
            queryParameters: {'per_page': 100},
          ),
          _apiService.client.get(
            '/warehouses',
            queryParameters: {'per_page': 100},
          ),
        ]);
        _inventory = responses[0].data['data'] ?? [];
        _products = responses[1].data['data'] ?? [];
        _warehouses = responses[2].data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading inventory: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredInventory {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _inventory;
    return _inventory.where((item) {
      final product = item['product'] as Map<String, dynamic>?;
      final warehouse = item['warehouse'] as Map<String, dynamic>?;
      return '${product?['name'] ?? ''} ${product?['sku'] ?? ''} ${warehouse?['name'] ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _showAdjustDialog({dynamic inventoryItem}) async {
    String? productId = inventoryItem?['product_id'] as String?;
    String? warehouseId = inventoryItem?['warehouse_id'] as String?;
    final quantityController = TextEditingController();
    final notesController = TextEditingController(
      text: 'Manual stock adjustment',
    );

    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust Inventory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: productId,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: _products.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem(
                      value: product['id'] as String,
                      child: Text(
                        '${product['name'] ?? 'Product'} (${product['sku'] ?? 'SKU'})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setDialogState(() => productId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: warehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                  items: _warehouses.map<DropdownMenuItem<String>>((warehouse) {
                    return DropdownMenuItem(
                      value: warehouse['id'] as String,
                      child: Text(warehouse['name'] ?? 'Warehouse'),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setDialogState(() => warehouseId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity Change',
                    helperText:
                        'Use positive to add stock, negative to reduce.',
                    prefixIcon: Icon(Icons.add_chart_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Apply'),
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text.trim());
                if (productId == null ||
                    warehouseId == null ||
                    quantity == null ||
                    quantity == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Choose product, warehouse, and non-zero quantity.',
                      ),
                    ),
                  );
                  return;
                }
                try {
                  if (!_apiService.mockMode) {
                    await _apiService.client.post(
                      '/inventory/adjust',
                      data: {
                        'product_id': productId,
                        'warehouse_id': warehouseId,
                        'quantity': quantity,
                        'notes': notesController.text.trim(),
                      },
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Inventory adjustment failed: $e'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    notesController.dispose();

    if (success == true) {
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory updated from live backend.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _showWarehouseDialog({dynamic warehouse}) async {
    final nameController = TextEditingController(
      text: warehouse?['name'] ?? '',
    );
    final locationController = TextEditingController(
      text: warehouse?['location'] ?? '',
    );
    bool isActive =
        warehouse?['is_active'] == true || warehouse?['is_active'] == 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(warehouse == null ? 'New Warehouse' : 'Edit Warehouse'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Warehouse Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: isActive,
                onChanged: (value) => setDialogState(() => isActive = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim(),
                  'is_active': isActive,
                };
                try {
                  if (!_apiService.mockMode) {
                    if (warehouse == null) {
                      await _apiService.client.post('/warehouses', data: data);
                    } else {
                      await _apiService.client.put(
                        '/warehouses/${warehouse['id']}',
                        data: data,
                      );
                    }
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Warehouse save failed: $e')),
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
    locationController.dispose();

    if (saved == true) {
      await _fetchData();
    }
  }

  Future<void> _deleteWarehouse(dynamic warehouse) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warehouse'),
        content: Text('Delete ${warehouse['name']}?'),
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
        await _apiService.client.delete('/warehouses/${warehouse['id']}');
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Warehouse delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredInventory;
    final lowStockCount = _inventory.where((item) {
      final qty = (item['quantity'] ?? 0) as int;
      final minStock = (item['min_stock'] ?? 0) as int;
      return qty <= minStock;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-inventory-adjust',
        onPressed: _showAdjustDialog,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Adjust Stock'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InventoryMetric(
                          label: 'Stock Records',
                          value: '${_inventory.length}',
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InventoryMetric(
                          label: 'Low Stock',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: lowStockCount > 0
                              ? AppColors.error
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search live inventory',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildWarehouseSection(),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(child: Text('No inventory records found'))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildInventoryCard(items[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(dynamic item) {
    final product = item['product'] as Map<String, dynamic>? ?? {};
    final warehouse = item['warehouse'] as Map<String, dynamic>? ?? {};
    final qty = (item['quantity'] ?? 0) as int;
    final minStock = (item['min_stock'] ?? 0) as int;
    final maxStock = (item['max_stock'] ?? 0) as int;
    final isLow = qty <= minStock;
    final fill = maxStock <= 0 ? 0.0 : (qty / maxStock).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (isLow ? AppColors.error : AppColors.secondary)
                          .withOpacity(0.12),
                  child: Icon(
                    isLow
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_rounded,
                    color: isLow ? AppColors.error : AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Unknown Product',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'SKU: ${product['sku'] ?? 'N/A'} | ${warehouse['name'] ?? 'Warehouse'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$qty',
                  style: TextStyle(
                    color: isLow ? AppColors.error : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.16),
              valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? AppColors.error : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Min $minStock | Max $maxStock',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAdjustDialog(inventoryItem: item),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Adjust'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Warehouses',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showWarehouseDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
        SizedBox(
          height: 96,
          child: _warehouses.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No warehouses configured',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _warehouses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final warehouse = _warehouses[index];
                    final active =
                        warehouse['is_active'] == true ||
                        warehouse['is_active'] == 1;
                    return SizedBox(
                      width: 240,
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.warehouse_rounded,
                            color: active
                                ? AppColors.primary
                                : AppColors.textLight,
                          ),
                          title: Text(
                            warehouse['name'] ?? 'Warehouse',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            warehouse['location'] ?? 'No location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showWarehouseDialog(warehouse: warehouse);
                              } else if (value == 'delete') {
                                _deleteWarehouse(warehouse);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InventoryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
