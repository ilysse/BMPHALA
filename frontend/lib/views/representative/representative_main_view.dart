import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/representative_provider.dart';
import '../shared/app_back_guard.dart';
import '../shared/location_picker_fields.dart';
import '../shared/order_detail_view.dart';

class RepresentativeMainView extends StatefulWidget {
  const RepresentativeMainView({super.key});

  @override
  State<RepresentativeMainView> createState() => _RepresentativeMainViewState();
}

class _RepresentativeMainViewState extends State<RepresentativeMainView> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RepresentativeProvider>(context, listen: false).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final tabs = _availableTabs(context, user);
    final selectedIndex = tabs.isEmpty || _currentIndex >= tabs.length
        ? 0
        : _currentIndex;

    return AppBackGuard(
      isAtRoot: selectedIndex == 0,
      onBackToRoot: () => setState(() => _currentIndex = 0),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            tabs.isEmpty
                ? context.tr('representative_workspace')
                : tabs[selectedIndex].title,
            overflow: TextOverflow.ellipsis,
          ),
          leading: const Icon(Icons.badge_rounded, color: AppColors.primary),
          actions: [
            IconButton(
              tooltip: context.tr('refresh'),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => Provider.of<RepresentativeProvider>(
                context,
                listen: false,
              ).refresh(),
            ),
            IconButton(
              tooltip: context.tr('sign_out'),
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              onPressed: auth.logout,
            ),
          ],
        ),
        body: tabs.isEmpty
            ? const _FeatureUnavailable(
                text:
                    'All optional representative workspace features are disabled. Contact an admin for access.',
              )
            : tabs[selectedIndex].view,
        bottomNavigationBar: tabs.isEmpty
            ? null
            : NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                destinations: tabs.map((tab) => tab.destination).toList(),
              ),
      ),
    );
  }

  List<_RepWorkspaceTab> _availableTabs(BuildContext context, User? user) {
    final currentUser = user;
    if (currentUser == null) return const [];

    return [
      if (currentUser.featureEnabled('dashboard'))
        _RepWorkspaceTab(
          title: context.tr('representative_workspace'),
          view: _RepresentativeDashboardTab(),
          destination: NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: context.tr('dashboard'),
          ),
        ),
      if (currentUser.featureEnabled('retailers'))
        _RepWorkspaceTab(
          title: context.tr('assigned_retailers'),
          view: _RepresentativeRetailersTab(),
          destination: NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: context.tr('retailers'),
          ),
        ),
      if (currentUser.featureEnabled('orders'))
        _RepWorkspaceTab(
          title: context.tr('orders_cash'),
          view: _RepresentativeOrdersTab(),
          destination: NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: context.tr('orders'),
          ),
        ),
      if (currentUser.featureEnabled('onboarding'))
        _RepWorkspaceTab(
          title: context.tr('onboard_shop'),
          view: _RepresentativeOnboardTab(),
          destination: NavigationDestination(
            icon: Icon(Icons.person_add_alt_1_outlined),
            selectedIcon: Icon(Icons.person_add_alt_1_rounded),
            label: context.tr('onboard'),
          ),
        ),
    ];
  }
}

class _RepWorkspaceTab {
  final String title;
  final Widget view;
  final NavigationDestination destination;

  const _RepWorkspaceTab({
    required this.title,
    required this.view,
    required this.destination,
  });
}

class _RepresentativeDashboardTab extends StatelessWidget {
  const _RepresentativeDashboardTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final rep = Provider.of<RepresentativeProvider>(context);
    final user = auth.currentUser;

    return _RepresentativeShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceHeader(user: user),
          const SizedBox(height: 16),
          _MetricGrid(
            metrics: [
              _MetricData(
                label: 'Retailers',
                value: '${rep.activeRetailerCount}',
                icon: Icons.storefront_rounded,
                color: AppColors.primary,
              ),
              _MetricData(
                label: 'Open Orders',
                value: '${rep.openOrderCount}',
                icon: Icons.pending_actions_rounded,
                color: AppColors.secondary,
              ),
              _MetricData(
                label: 'Outstanding',
                value: '${rep.outstandingBalance.toStringAsFixed(0)} DH',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.accent,
              ),
              _MetricData(
                label: 'Unpaid',
                value: '${rep.unpaidOrderCount}',
                icon: Icons.payments_rounded,
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CashAccessBanner(enabled: user?.canCollectCash ?? false),
          const SizedBox(height: 20),
          Text(
            'Recent scoped orders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (rep.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (rep.orders.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              text: 'No orders from your retailers yet.',
            )
          else
            ...rep.orders.take(4).map((order) => _OrderTile(order: order)),
        ],
      ),
    );
  }
}

class _RepresentativeRetailersTab extends StatelessWidget {
  const _RepresentativeRetailersTab();

  @override
  Widget build(BuildContext context) {
    final rep = Provider.of<RepresentativeProvider>(context);

    return _RepresentativeShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My retailers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (rep.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (rep.retailers.isEmpty)
            const _EmptyState(
              icon: Icons.storefront_outlined,
              text: 'No retailers are assigned to you yet.',
            )
          else
            ...rep.retailers.map((retailer) {
              final orders = rep.ordersForRetailer(retailer.id);
              final outstanding = orders.fold(
                0.0,
                (sum, order) => sum + order.remainingBalance,
              );
              return _RetailerTile(
                retailer: retailer,
                orderCount: orders.length,
                outstanding: outstanding,
              );
            }),
        ],
      ),
    );
  }
}

class _RepresentativeOrdersTab extends StatefulWidget {
  const _RepresentativeOrdersTab();

  @override
  State<_RepresentativeOrdersTab> createState() =>
      _RepresentativeOrdersTabState();
}

class _RepresentativeOrdersTabState extends State<_RepresentativeOrdersTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final rep = Provider.of<RepresentativeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final orders = _filteredOrders(rep.orders);

    return _RepresentativeShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                value: 'all',
                selected: _filter,
                onTap: _setFilter,
              ),
              _FilterChip(
                label: 'Unpaid',
                value: 'unpaid',
                selected: _filter,
                onTap: _setFilter,
              ),
              _FilterChip(
                label: 'Active',
                value: 'active',
                selected: _filter,
                onTap: _setFilter,
              ),
              _FilterChip(
                label: 'Delivered',
                value: 'delivered',
                selected: _filter,
                onTap: _setFilter,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rep.error != null)
            _InlineNotice(text: rep.error!, color: AppColors.error),
          if (rep.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (orders.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              text: 'No orders match this view.',
            )
          else
            ...orders.map(
              (order) => _OrderTile(
                order: order,
                showCashAction:
                    (auth.currentUser?.canCollectCash ?? false) &&
                    order.remainingBalance > 0 &&
                    order.status != OrderStatus.cancelled,
                onCollectCash: () => _showCashDialog(context, order),
              ),
            ),
        ],
      ),
    );
  }

  void _setFilter(String value) {
    setState(() => _filter = value);
  }

  List<Order> _filteredOrders(List<Order> orders) {
    switch (_filter) {
      case 'unpaid':
        return orders.where((order) => order.remainingBalance > 0).toList();
      case 'active':
        return orders
            .where(
              (order) =>
                  order.status != OrderStatus.delivered &&
                  order.status != OrderStatus.cancelled,
            )
            .toList();
      case 'delivered':
        return orders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();
      default:
        return orders;
    }
  }

  Future<void> _showCashDialog(BuildContext context, Order order) async {
    final amountController = TextEditingController(
      text: order.remainingBalance.toStringAsFixed(2),
    );
    final notesController = TextEditingController();

    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Cash Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${order.retailerName}\nOutstanding ${order.remainingBalance.toStringAsFixed(2)} DH',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Collected Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Record Cash'),
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;
              final ok =
                  await Provider.of<RepresentativeProvider>(
                    context,
                    listen: false,
                  ).recordCashPayment(
                    order: order,
                    amount: amount,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(ok);
            },
          ),
        ],
      ),
    );

    amountController.dispose();
    notesController.dispose();

    if (!context.mounted || success == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cash collection recorded.'
              : 'Cash collection was not recorded.',
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }
}

class _RepresentativeOnboardTab extends StatefulWidget {
  const _RepresentativeOnboardTab();

  @override
  State<_RepresentativeOnboardTab> createState() =>
      _RepresentativeOnboardTabState();
}

class _RepresentativeOnboardTabState extends State<_RepresentativeOnboardTab> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'password');
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final referralCode = auth.currentUser?.referralCode ?? auth.currentUser?.id;

    return _RepresentativeShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Register a retailer under your responsibility',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Referral: ${referralCode ?? 'Not available'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Retailer Phone',
                hintText: 'e.g. 0612345678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => value == null || value.trim().length < 8
                  ? 'Valid phone required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Retailer Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Valid email required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value == null || value.length < 8
                  ? '8 characters minimum'
                  : null,
            ),
            const SizedBox(height: 12),
            LocationPickerFields(
              addressController: _addressController,
              latitudeController: _latitudeController,
              longitudeController: _longitudeController,
              addressLabel: 'Retailer Address',
              required: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Register Retailer'),
              onPressed: auth.isLoading || referralCode == null
                  ? null
                  : () => _submit(context, referralCode),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, String referralCode) async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.onboardRetailer(
      shopName: _shopNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      referralCode: referralCode,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      latitude: _latitudeController.text.trim().isEmpty
          ? null
          : double.parse(_latitudeController.text.trim()),
      longitude: _longitudeController.text.trim().isEmpty
          ? null
          : double.parse(_longitudeController.text.trim()),
    );

    if (!context.mounted) return;
    if (success) {
      _shopNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      await Provider.of<RepresentativeProvider>(
        context,
        listen: false,
      ).refresh();
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Retailer registered and assigned to you.'
              : auth.error ?? 'Retailer registration failed.',
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }
}

class _RepresentativeShell extends StatelessWidget {
  final Widget child;

  const _RepresentativeShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => Provider.of<RepresentativeProvider>(
          context,
          listen: false,
        ).refresh(),
        child: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final User? user;

  const _WorkspaceHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.tealGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          Text(
            user?.username ?? 'Representative',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? 'sales representative',
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isWide ? 1.65 : 1.35,
          children: metrics
              .map(
                (metric) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(metric.icon, color: metric.color),
                        Text(
                          metric.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _CashAccessBanner extends StatelessWidget {
  final bool enabled;

  const _CashAccessBanner({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return _InlineNotice(
      color: enabled ? AppColors.secondary : AppColors.accent,
      text: enabled
          ? 'Cash collection is enabled for this representative account.'
          : 'Cash collection is disabled. Admin must enable it before you can record cash.',
    );
  }
}

class _RetailerTile extends StatelessWidget {
  final User retailer;
  final int orderCount;
  final double outstanding;

  const _RetailerTile({
    required this.retailer,
    required this.orderCount,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = retailer.latitude != null && retailer.longitude != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
        ),
        title: Text(
          retailer.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            retailer.email,
            if (retailer.address != null) retailer.address!,
            hasLocation ? 'Map location verified' : 'Location missing',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$orderCount orders',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${outstanding.toStringAsFixed(0)} DH',
              style: TextStyle(
                color: outstanding > 0 ? AppColors.accent : AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final bool showCashAction;
  final VoidCallback? onCollectCash;

  const _OrderTile({
    required this.order,
    this.showCashAction = false,
    this.onCollectCash,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailView(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber ?? order.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _StatusPill(label: order.status.name, color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.retailerName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.deliveryAddress != null) ...[
                const SizedBox(height: 4),
                Text(
                  order.deliveryAddress!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textLight),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.totalAmount.toStringAsFixed(2)} DH',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'Due ${order.remainingBalance.toStringAsFixed(2)} DH',
                    style: TextStyle(
                      color: order.remainingBalance > 0
                          ? AppColors.accent
                          : AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (showCashAction) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onCollectCash,
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('Collect Cash'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.accent;
      case OrderStatus.approved:
        return AppColors.primary;
      case OrderStatus.outForDelivery:
        return AppColors.secondary;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onTap(value),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String text;
  final Color color;

  const _InlineNotice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureUnavailable extends StatelessWidget {
  final String text;

  const _FeatureUnavailable({required this.text});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
