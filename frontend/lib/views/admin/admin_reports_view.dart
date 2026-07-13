import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';
import '../../models/order.dart';
import '../shared/order_detail_view.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _minTotalController = TextEditingController();
  final TextEditingController _maxTotalController = TextEditingController();
  
  List<dynamic> _retailers = [];
  List<dynamic> _brands = [];
  List<dynamic> _categories = [];
  List<dynamic> _representatives = [];
  List<Order> _filteredOrders = [];
  
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  String? _retailerId;
  String? _brandId;
  String? _categoryId;
  String? _representativeId;
  String _searchQuery = '';
  
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDateController.text = _date(now.subtract(const Duration(days: 30)));
    _toDateController.text = _date(now);
    
    _fetchLookups();
    _fetchFilteredOrders();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _minTotalController.dispose();
    _maxTotalController.dispose();
    super.dispose();
  }

  Future<void> _fetchLookups() async {
    if (_apiService.mockMode) {
      _retailers = [
        {'id': 'RET1', 'name': 'Corner Market Inc.'},
        {'id': 'RET2', 'name': 'Downtown Superette'}
      ];
      _brands = [
        {'id': 'B1', 'name': 'Halawat'}
      ];
      _categories = [
        {'id': 'C1', 'name': 'Sweets'}
      ];
      _representatives = [
        {'id': 'REP1', 'name': 'Jean SalesRep'}
      ];
      setState(() {});
      return;
    }
    try {
      final responses = await Future.wait([
        _apiService.client.get('/users', queryParameters: {'role': 'retailer', 'per_page': 100}),
        _apiService.client.get('/brands', queryParameters: {'per_page': 100}),
        _apiService.client.get('/categories', queryParameters: {'per_page': 100}),
        _apiService.client.get('/users', queryParameters: {'role': 'sales_rep', 'per_page': 100}),
      ]);
      if (mounted) {
        setState(() {
          _retailers = responses[0].data['data'] ?? [];
          _brands = responses[1].data['data'] ?? [];
          _categories = responses[2].data['data'] ?? [];
          _representatives = responses[3].data['data'] ?? [];
        });
      }
    } catch (e) {
      // Quiet fail or handle error
    }
  }

  Future<void> _fetchFilteredOrders() async {
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);
    try {
      final query = <String, dynamic>{
        'per_page': 100,
        if (_searchQuery.trim().isNotEmpty) 'search': _searchQuery.trim(),
        if (_fromDateController.text.trim().isNotEmpty) 'from': _fromDateController.text.trim(),
        if (_toDateController.text.trim().isNotEmpty) 'to': _toDateController.text.trim(),
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_paymentFilter != 'all') 'payment_status': _paymentFilter,
        if (_retailerId != null) 'retailer_id': _retailerId,
        if (_brandId != null) 'brand_id': _brandId,
        if (_categoryId != null) 'category_id': _categoryId,
        if (_representativeId != null) 'representative_id': _representativeId,
        if (_minTotalController.text.trim().isNotEmpty) 'min_total': _minTotalController.text.trim(),
        if (_maxTotalController.text.trim().isNotEmpty) 'max_total': _maxTotalController.text.trim(),
      };

      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        final allMockOrders = [
          Order(
            id: 'ORD-VIII8HAGE',
            orderNumber: 'ORD-VIII8HAGE',
            retailerId: 'RET1',
            retailerName: 'Superette Express',
            items: [],
            totalAmount: 23.58,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          Order(
            id: 'ORD-ATE4NIL9',
            orderNumber: 'ORD-ATE4NIL9',
            retailerId: 'RET2',
            retailerName: 'ilyas',
            items: [],
            totalAmount: 35.60,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          Order(
            id: 'ORD-DELIVERED1',
            orderNumber: 'ORD-DELIVERED1',
            retailerId: 'RET1',
            retailerName: 'Superette Express',
            items: [],
            totalAmount: 150.00,
            status: OrderStatus.delivered,
            paymentStatus: PaymentStatus.paid,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          Order(
            id: 'ORD-PENDING1',
            orderNumber: 'ORD-PENDING1',
            retailerId: 'RET3',
            retailerName: 'Boutique Marrakech',
            items: [],
            totalAmount: 89.90,
            status: OrderStatus.pending,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          Order(
            id: 'ORD-CANCELLED1',
            orderNumber: 'ORD-CANCELLED1',
            retailerId: 'RET2',
            retailerName: 'ilyas',
            items: [],
            totalAmount: 45.00,
            status: OrderStatus.cancelled,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        var filtered = allMockOrders.toList();
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filtered = filtered.where((o) =>
            (o.orderNumber ?? '').toLowerCase().contains(q) ||
            o.retailerName.toLowerCase().contains(q)
          ).toList();
        }
        if (_statusFilter != 'all') {
          filtered = filtered.where((o) => o.status.name == _statusFilter).toList();
        }
        if (_paymentFilter != 'all') {
          filtered = filtered.where((o) => o.paymentStatus.name == _paymentFilter).toList();
        }
        _filteredOrders = filtered;
      } else {
        final response = await _apiService.client.get('/orders', queryParameters: query);
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] ?? [];
          _filteredOrders = data.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Quiet fail or logged
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => controller.text = _date(picked));
    }
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFiltersPanel(),
    );
  }

  Widget _buildFiltersPanel() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) {
              return Column(
                children: [
                  AppBar(
                    title: Text(context.tr('filters') == 'filters' ? 'Filters' : context.tr('filters')),
                    automaticallyImplyLeading: false,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _statusFilter = 'all';
                            _paymentFilter = 'all';
                            _retailerId = null;
                            _brandId = null;
                            _categoryId = null;
                            _representativeId = null;
                            _minTotalController.clear();
                            _maxTotalController.clear();
                            final now = DateTime.now();
                            _fromDateController.text = _date(now.subtract(const Duration(days: 30)));
                            _toDateController.text = _date(now);
                          });
                        },
                        child: Text(context.tr('reset')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _dateField(
                                label: context.tr('date_from'),
                                controller: _fromDateController,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _dateField(
                                label: context.tr('date_to'),
                                controller: _toDateController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          label: context.tr('status'),
                          value: _statusFilter,
                          items: {
                            'all': context.tr('all'),
                            'pending': context.tr('status_pending'),
                            'confirmed': context.tr('status_confirmed'),
                            'assigned': context.tr('status_assigned'),
                            'in_transit': context.tr('status_in_transit'),
                            'delivered': context.tr('status_delivered'),
                            'cancelled': context.tr('status_cancelled'),
                          },
                          onChanged: (value) => setModalState(() => _statusFilter = value),
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          label: context.tr('payment'),
                          value: _paymentFilter,
                          items: {
                            'all': context.tr('all'),
                            'unpaid': context.tr('payment_unpaid'),
                            'partially_paid': context.tr('payment_partially_paid'),
                            'paid': context.tr('payment_paid'),
                          },
                          onChanged: (value) => setModalState(() => _paymentFilter = value),
                        ),
                        const SizedBox(height: 16),
                        _entityDropdown(
                          label: context.tr('retailer'),
                          value: _retailerId,
                          rows: _retailers,
                          onChanged: (value) => setModalState(() => _retailerId = value),
                        ),
                        const SizedBox(height: 16),
                        _entityDropdown(
                          label: context.tr('role_sales_rep'),
                          value: _representativeId,
                          rows: _representatives,
                          onChanged: (value) => setModalState(() => _representativeId = value),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _entityDropdown(
                                label: context.tr('brand'),
                                value: _brandId,
                                rows: _brands,
                                onChanged: (value) => setModalState(() => _brandId = value),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _entityDropdown(
                                label: context.tr('category'),
                                value: _categoryId,
                                rows: _categories,
                                onChanged: (value) => setModalState(() => _categoryId = value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minTotalController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: context.tr('min_total')),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _maxTotalController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: context.tr('max_total')),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _fetchFilteredOrders();
                            setState(() {}); // to update total
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(context.tr('apply')),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double ordersTotal = _filteredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final String filtersText = '${context.tr('filters') == 'filters' ? 'Filters' : context.tr('filters')} (Total: ${ordersTotal.toStringAsFixed(0)} DH)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('orders') == 'orders' ? 'Orders' : context.tr('orders')),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.tr('search_crm'),
                prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _fetchFilteredOrders();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _showFiltersBottomSheet,
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: Text(filtersText),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? Center(child: Text(context.tr('no_orders_yet')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(_filteredOrders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    Color paymentColor = AppColors.error;
    if (order.paymentStatus == PaymentStatus.paid) {
      paymentColor = Colors.green;
    } else if (order.paymentStatus == PaymentStatus.partiallyPaid) {
      paymentColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailView(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber ?? 'Order #${order.id.substring(0, 5)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.retailerName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                  Text(
                    '${order.totalAmount.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('payment_summary'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    context.tr('payment_${order.paymentStatus.name.toLowerCase()}'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: paymentColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color statusColor = AppColors.primary;
    switch (status) {
      case OrderStatus.pending:
        statusColor = Colors.blue;
        break;
      case OrderStatus.approved:
        statusColor = Colors.green;
        break;
      case OrderStatus.outForDelivery:
        statusColor = Colors.purple;
        break;
      case OrderStatus.delivered:
        statusColor = Colors.amber;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.tr('status_${status.name.toLowerCase()}'),
        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: () => _pickDate(controller),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: items.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _entityDropdown({
    required String label,
    required String? value,
    required List<dynamic> rows,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(context.tr('all'))),
        ...rows.map(
          (row) => DropdownMenuItem<String?>(
            value: row['id'] as String?,
            child: Text(
              '${row['name'] ?? row['username'] ?? 'Item'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
