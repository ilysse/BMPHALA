import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';

class AdminProcurementView extends StatefulWidget {
  const AdminProcurementView({super.key});

  @override
  State<AdminProcurementView> createState() => _AdminProcurementViewState();
}

class _AdminProcurementViewState extends State<AdminProcurementView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _purchaseOrders = [];
  List<dynamic> _suppliers = [];
  List<dynamic> _products = [];
  List<dynamic> _warehouses = [];
  Map<String, dynamic> _stats = {};
  String _statusFilter = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _stats = {
          'open_purchase_orders': 4,
          'ordered_value': 42800,
          'received_value': 120600,
          'supplier_count': 8,
        };
        _purchaseOrders = [];
      } else {
        final query = <String, dynamic>{
          'per_page': 100,
          if (_statusFilter != 'all') 'status': _statusFilter,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
        };
        final responses = await Future.wait([
          _apiService.client.get('/purchase-orders', queryParameters: query),
          _apiService.client.get('/purchase-orders/stats'),
          _apiService.client.get(
            '/suppliers',
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
        _purchaseOrders = responses[0].data['data'] ?? [];
        _stats = responses[1].data['data'] ?? {};
        _suppliers = responses[2].data['data'] ?? [];
        _products = responses[3].data['data'] ?? [];
        _warehouses = responses[4].data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load procurement: $e')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _showSupplierDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final termsController = TextEditingController(text: '30');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                nameController,
                'Supplier Name',
                Icons.business_rounded,
              ),
              _dialogField(
                contactController,
                'Contact Person',
                Icons.person_rounded,
              ),
              _dialogField(phoneController, 'Phone', Icons.phone_rounded),
              _dialogField(emailController, 'Email', Icons.email_rounded),
              _dialogField(addressController, 'Address', Icons.place_rounded),
              _dialogField(
                termsController,
                'Payment Terms Days',
                Icons.event_repeat_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                if (!_apiService.mockMode) {
                  await _apiService.client.post(
                    '/suppliers',
                    data: {
                      'name': nameController.text.trim(),
                      'contact_person': contactController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'email': emailController.text.trim(),
                      'address': addressController.text.trim(),
                      'payment_terms_days':
                          int.tryParse(termsController.text.trim()) ?? 30,
                    },
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Supplier save failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );

    nameController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    termsController.dispose();
    if (created == true) await _fetchData();
  }

  Future<void> _showPurchaseOrderDialog() async {
    String? supplierId = _suppliers.isNotEmpty
        ? '${_suppliers.first['id']}'
        : null;
    String? warehouseId = _warehouses.isNotEmpty
        ? '${_warehouses.first['id']}'
        : null;
    final expectedController = TextEditingController(
      text: _date(DateTime.now().add(const Duration(days: 7))),
    );
    final taxController = TextEditingController(text: '0');
    final shippingController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    final lines = <_PurchaseLine>[_PurchaseLine()];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('New Purchase Order'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: supplierId,
                    decoration: const InputDecoration(labelText: 'Supplier'),
                    items: _suppliers.map<DropdownMenuItem<String>>((supplier) {
                      return DropdownMenuItem(
                        value: '${supplier['id']}',
                        child: Text(
                          '${supplier['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setModalState(() => supplierId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: warehouseId,
                    decoration: const InputDecoration(
                      labelText: 'Receiving Warehouse',
                    ),
                    items: _warehouses.map<DropdownMenuItem<String>>((
                      warehouse,
                    ) {
                      return DropdownMenuItem(
                        value: '${warehouse['id']}',
                        child: Text(
                          '${warehouse['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setModalState(() => warehouseId = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expectedController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Expected Date',
                      prefixIcon: const Icon(Icons.event_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(expectedController.text) ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setModalState(
                              () => expectedController.text = _date(picked),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < lines.length; i++)
                    _lineEditor(lines, i, setModalState),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setModalState(() => lines.add(_PurchaseLine())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add line'),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          taxController,
                          'Tax',
                          Icons.percent_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          shippingController,
                          'Shipping',
                          Icons.local_shipping_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _dialogField(notesController, 'Notes', Icons.notes_rounded),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: const Text('Create PO'),
              onPressed: () async {
                final validLines = lines
                    .where((line) => line.productId != null)
                    .toList();
                if (supplierId == null ||
                    warehouseId == null ||
                    validLines.isEmpty) {
                  return;
                }
                try {
                  if (!_apiService.mockMode) {
                    await _apiService.client.post(
                      '/purchase-orders',
                      data: {
                        'supplier_id': supplierId,
                        'warehouse_id': warehouseId,
                        'expected_at': expectedController.text.trim(),
                        'tax_amount':
                            double.tryParse(taxController.text.trim()) ?? 0,
                        'shipping_amount':
                            double.tryParse(shippingController.text.trim()) ??
                            0,
                        'notes': notesController.text.trim(),
                        'items': validLines
                            .map((line) => line.toJson())
                            .toList(),
                      },
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purchase order failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    expectedController.dispose();
    taxController.dispose();
    shippingController.dispose();
    notesController.dispose();
    for (final line in lines) {
      line.dispose();
    }
    if (created == true) await _fetchData();
  }

  Widget _lineEditor(
    List<_PurchaseLine> lines,
    int index,
    StateSetter setModalState,
  ) {
    final line = lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem(
                      value: '${product['id']}',
                      child: Text(
                        '${product['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setModalState(() => line.productId = value),
                ),
              ),
              IconButton(
                tooltip: 'Remove line',
                onPressed: lines.length == 1
                    ? null
                    : () => setModalState(() {
                        line.dispose();
                        lines.removeAt(index);
                      }),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: line.costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unit Cost'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _receivePurchaseOrder(dynamic order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Purchase Order'),
        content: Text(
          'Receive all remaining quantities for ${order['po_number']} into warehouse stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.move_to_inbox_rounded),
            label: const Text('Receive'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.post(
          '/purchase-orders/${order['id']}/receive',
        );
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receiving failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPurchaseOrderDialog,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Purchase Order'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Procurement',
                      style: Theme.of(
                        context,
                      ).textTheme.displayLarge?.copyWith(fontSize: 26),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Add supplier',
                    onPressed: _showSupplierDialog,
                    icon: const Icon(Icons.business_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetrics(),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search supplier or PO',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _fetchData,
                  ),
                ),
                onSubmitted: (_) => _fetchData(),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in const [
                      'all',
                      'draft',
                      'ordered',
                      'partially_received',
                      'received',
                      'cancelled',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: _statusFilter == status,
                          onSelected: (_) {
                            setState(() => _statusFilter = status);
                            _fetchData();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_purchaseOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No purchase orders yet'),
                  ),
                )
              else
                ..._purchaseOrders.map(_purchaseOrderCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 720 ? 4 : 2,
      childAspectRatio: 1.7,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _metricCard(
          'Open POs',
          '${_stats['open_purchase_orders'] ?? 0}',
          Icons.pending_actions_rounded,
        ),
        _metricCard(
          'Ordered',
          '${_money(_stats['ordered_value'])} DH',
          Icons.shopping_cart_rounded,
        ),
        _metricCard(
          'Received',
          '${_money(_stats['received_value'])} DH',
          Icons.inventory_rounded,
        ),
        _metricCard(
          'Suppliers',
          '${_stats['supplier_count'] ?? _suppliers.length}',
          Icons.business_rounded,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    label,
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

  Widget _purchaseOrderCard(dynamic order) {
    final items = (order['items'] as List<dynamic>? ?? []);
    final status = '${order['status'] ?? 'ordered'}';
    final canReceive = status != 'received' && status != 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order['po_number'] ?? 'PO'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: _statusColor(status).withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order['supplier']?['name'] ?? 'Supplier'} -> ${order['warehouse']?['name'] ?? 'Warehouse'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...items.take(3).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item['product']?['name'] ?? 'Product'} | ordered ${item['quantity_ordered']} | received ${item['quantity_received']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_money(order['total_amount'])} DH',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: canReceive
                      ? () => _receivePurchaseOrder(order)
                      : null,
                  icon: const Icon(Icons.move_to_inbox_rounded),
                  label: const Text('Receive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      case 'partially_received':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  String _money(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    if (value is String) {
      return (double.tryParse(value) ?? 0).toStringAsFixed(0);
    }
    return '0';
  }
}

class _PurchaseLine {
  String? productId;
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController costController = TextEditingController(text: '0');

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity_ordered': int.tryParse(quantityController.text.trim()) ?? 1,
      'unit_cost': double.tryParse(costController.text.trim()) ?? 0,
    };
  }

  void dispose() {
    quantityController.dispose();
    costController.dispose();
  }
}
