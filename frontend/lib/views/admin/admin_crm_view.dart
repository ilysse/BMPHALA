import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import 'admin_password_reset_dialog.dart';

class AdminCrmView extends StatefulWidget {
  const AdminCrmView({super.key});

  @override
  State<AdminCrmView> createState() => _AdminCrmViewState();
}

class _AdminCrmViewState extends State<AdminCrmView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<User> _retailers = [];
  List<Order> _orders = [];
  String _statusFilter = 'all';
  bool _isLoading = false;
  String? _approvingUserId;

  // Optimized lookup cache & total pre-calculated variables
  final Map<String, List<Order>> _retailerOrdersMap = {};
  double _totalDebt = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCrm();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCrm() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _retailers = [
          User(
            id: 'RET_001',
            username: 'Corner Market Inc.',
            email: 'corner@halawat.ma',
            role: UserRole.retailer,
            address: 'Casablanca',
          ),
        ];
        _orders = [];
      } else {
        final responses = await Future.wait([
          _apiService.client.get(
            '/users',
            queryParameters: {'role': 'retailer', 'per_page': 100},
          ),
          _apiService.client.get('/orders', queryParameters: {'per_page': 100}),
        ]);
        _retailers = (responses[0].data['data'] as List<dynamic>? ?? [])
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
        _orders = (responses[1].data['data'] as List<dynamic>? ?? [])
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Optimize: Index orders in a map for O(1) retailer lookups
      _retailerOrdersMap.clear();
      for (var order in _orders) {
        _retailerOrdersMap.putIfAbsent(order.retailerId, () => []).add(order);
      }

      // Optimize: Pre-calculate total outstanding debt to avoid heavy builds
      _totalDebt = 0.0;
      for (var retailer in _retailers) {
        final rOrders = _ordersFor(retailer.id);
        for (var order in rOrders) {
          _totalDebt += order.remainingBalance;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('crm_load_failed')}: $e')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<User> get _filteredRetailers {
    final query = _searchController.text.trim().toLowerCase();
    return _retailers.where((retailer) {
      final retailerOrders = _ordersFor(retailer.id);
      final hasOpen = retailerOrders.any(
        (order) =>
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled,
      );
      final hasDebt = retailerOrders.any((order) => order.remainingBalance > 0);
      final matchesStatus =
          _statusFilter == 'all' ||
          (_statusFilter == 'open' && hasOpen) ||
          (_statusFilter == 'debt' && hasDebt) ||
          (_statusFilter == 'pending' && retailer.status == 'pending') ||
          (_statusFilter == 'pin_missing' &&
              (retailer.latitude == null || retailer.longitude == null));
      final searchable =
          '${retailer.username} ${retailer.email} ${retailer.address ?? ''}'
              .toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final retailers = _filteredRetailers;

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
                        child: _CrmMetric(
                          label: context.tr('customers'),
                          value: '${_retailers.length}',
                          icon: Icons.storefront_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CrmMetric(
                          label: context.tr('outstanding'),
                          value: '${_totalDebt.toStringAsFixed(0)} DH',
                          icon: Icons.account_balance_wallet_outlined,
                          color: _totalDebt > 0
                              ? AppColors.error
                              : AppColors.secondary,
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
                      children: [
                        _filterChip('all', context.tr('all')),
                        _filterChip('open', context.tr('open_orders')),
                        _filterChip('debt', context.tr('outstanding')),
                        _filterChip('pending', context.tr('status_pending')),
                        _filterChip('pin_missing', context.tr('pin_missing')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : retailers.isEmpty
                  ? Center(child: Text(context.tr('no_items')))
                  : RefreshIndicator(
                      onRefresh: _fetchCrm,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: retailers.length,
                        itemBuilder: (context, index) =>
                            _buildAccountCard(retailers[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _statusFilter == value,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }

  Widget _buildAccountCard(User retailer) {
    final orders = _ordersFor(retailer.id);
    final sales = orders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final debt = orders.fold<double>(
      0,
      (sum, order) => sum + order.remainingBalance,
    );
    final hasPin = retailer.latitude != null && retailer.longitude != null;
    final isPending = retailer.status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending
              ? Colors.orange.withOpacity(0.14)
              : hasPin
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.error.withOpacity(0.12),
          child: Icon(
            isPending
                ? Icons.hourglass_top_rounded
                : hasPin
                ? Icons.storefront_rounded
                : Icons.wrong_location_rounded,
            color: isPending
                ? Colors.orange.shade800
                : hasPin
                ? AppColors.primary
                : AppColors.error,
          ),
        ),
        title: Text(
          retailer.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${retailer.email.isNotEmpty ? retailer.email : retailer.phone ?? '-'} | ${orders.length} ${context.tr('orders')} | ${isPending ? context.tr('status_pending') : context.tr('active')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isPending
            ? FilledButton.icon(
                onPressed: _approvingUserId == retailer.id
                    ? null
                    : () => _approveRetailer(retailer),
                icon: _approvingUserId == retailer.id
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded, size: 18),
                label: Text(context.tr('approve_account')),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${sales.toStringAsFixed(0)} DH',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    debt > 0
                        ? '${debt.toStringAsFixed(0)} DH ${context.tr('due_status')}'
                        : context.tr('clear'),
                    style: TextStyle(
                      color: debt > 0 ? AppColors.error : AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
        onTap: () => _showAccount(retailer),
      ),
    );
  }

  Future<void> _approveRetailer(User retailer) async {
    if (_approvingUserId != null) return;
    setState(() => _approvingUserId = retailer.id);

    try {
      await _apiService.client.put('/users/${retailer.id}/approve');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('account_approved')),
          backgroundColor: AppColors.secondary,
        ),
      );
      await _fetchCrm();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('approval_failed')}: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _approvingUserId = null);
    }
  }

  void _showAccount(User retailer) {
    final orders = _ordersFor(retailer.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              retailer.username,
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              retailer.email.isNotEmpty
                  ? retailer.email
                  : retailer.phone ?? '-',
              style: const TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            if (retailer.status == 'pending') ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _approveRetailer(retailer);
                },
                icon: const Icon(Icons.verified_user_rounded),
                label: Text(context.tr('approve_account')),
              ),
              const SizedBox(height: 16),
            ],
            _InfoRow(
              label: context.tr('phone'),
              value: retailer.phone ?? 'N/A',
            ),
            _InfoRow(
              label: context.tr('address'),
              value: retailer.address ?? context.tr('missing'),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => showAdminPasswordResetDialog(
                  context: context,
                  user: retailer,
                ),
                icon: const Icon(Icons.lock_reset_rounded),
                label: Text(context.tr('reset_password')),
              ),
            ),
            _InfoRow(
              label: context.tr('pin'),
              value: retailer.latitude == null || retailer.longitude == null
                  ? context.tr('missing')
                  : '${retailer.latitude!.toStringAsFixed(5)}, ${retailer.longitude!.toStringAsFixed(5)}',
            ),
            const Divider(height: 28),
            Text(
              context.tr('recent_orders'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              Text(context.tr('no_orders_yet'))
            else
              ...orders
                  .take(10)
                  .map(
                    (order) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(order.orderNumber ?? order.id),
                      subtitle: Text(
                        context.tr(
                          order.status == OrderStatus.outForDelivery
                              ? 'status_in_transit'
                              : 'status_${order.status.name}',
                        ),
                      ),
                      trailing: Text(
                        '${order.totalAmount.toStringAsFixed(2)} DH',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  List<Order> _ordersFor(String retailerId) =>
      _retailerOrdersMap[retailerId] ?? const [];
}

class _CrmMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CrmMetric({
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
