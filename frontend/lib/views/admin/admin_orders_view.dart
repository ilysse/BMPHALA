import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';
import '../../models/order.dart';
import '../shared/order_detail_view.dart';
import '../../core/localization/app_localizations.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final List<Order> _orders = [];
  String _statusFilter = 'all';
  bool _isLoading = false;
  int _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetched = <Order>[];
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        fetched.addAll([
          Order(
            id: 'ORD_2001',
            orderNumber: 'ORD-2001',
            retailerId: 'RET_001',
            retailerName: 'Corner Market Inc.',
            items: [],
            totalAmount: 136.50,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            deliveryAddress: 'Central Market',
            deliveryLatitude: 33.5731,
            deliveryLongitude: -7.5898,
          ),
        ]);
        _totalOrders = fetched.length;
      } else {
        var page = 1;
        var lastPage = 1;
        do {
          final response = await _apiService.client.get(
            '/orders',
            queryParameters: {'per_page': 100, 'page': page},
          );
          final data = response.data['data'] as List<dynamic>? ?? [];
          fetched.addAll(
            data.map((json) => Order.fromJson(json as Map<String, dynamic>)),
          );
          final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
          _totalOrders = _intValue(meta['total']) ?? fetched.length;
          lastPage = _intValue(meta['last_page']) ?? page;
          page += 1;
        } while (page <= lastPage);
      }

      _orders
        ..clear()
        ..addAll(fetched);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load orders: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<Order> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders.where((order) {
      final status = order.status.name;
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      final searchable =
          '${order.retailerName} ${order.orderNumber ?? ''} ${order.id} ${order.deliveryAddress ?? ''}'
              .toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                        child: _OrderMetric(
                          label: context.tr('orders'),
                          value: '$_totalOrders',
                          icon: Icons.assignment_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OrderMetric(
                          label: context.tr('status_pending'),
                          value:
                              '${_orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length}',
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: context.tr('search_crm'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                'all',
                                'pending',
                                'approved',
                                'outForDelivery',
                                'delivered',
                                'cancelled',
                              ]
                              .map(
                                (status) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(_statusLabel(status)),
                                    selected: _statusFilter == status,
                                    onSelected: (_) =>
                                        setState(() => _statusFilter = status),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : orders.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: orders.length,
                        itemBuilder: (context, index) =>
                            _buildOrderCard(orders[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final hasPin =
        order.deliveryLatitude != null && order.deliveryLongitude != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showOrderDetails(order),
        leading: CircleAvatar(
          backgroundColor: _statusColor(order.status).withOpacity(0.12),
          child: Icon(Icons.storefront, color: _statusColor(order.status)),
        ),
        title: Text(
          order.retailerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${order.orderNumber ?? order.id} | ${_statusLabel(order.status.name)} | ${hasPin ? 'Pin saved' : 'No pin'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${order.totalAmount.toStringAsFixed(2)} DH',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _paymentLabel(order.paymentStatus),
              style: TextStyle(
                color: order.remainingBalance > 0
                    ? AppColors.error
                    : AppColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailView(order: order)),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.accent;
      case OrderStatus.approved:
        return AppColors.primary;
      case OrderStatus.outForDelivery:
        return AppColors.primaryLight;
      case OrderStatus.delivered:
        return AppColors.secondary;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _statusLabel(String status) {
    if (status == 'all') {
      return context.tr('all');
    }
    if (status == 'outForDelivery' || status == 'in_transit') {
      return context.tr('status_in_transit');
    }
    return context.tr('status_${status.toLowerCase()}');
  }

  String _paymentLabel(PaymentStatus status) {
    return context.tr('payment_${status.name.toLowerCase()}');
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _OrderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OrderMetric({
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
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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

