import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../shared/app_back_guard.dart';
import '../shared/location_picker_fields.dart';
import 'admin_metrics_view.dart';
import 'dashboard_view.dart';
import 'admin_reports_view.dart';
import 'admin_orders_view.dart';
import 'admin_crm_view.dart';
import 'admin_registrations_view.dart';
import 'dispatch_map_view.dart';
import 'sales_rep_performance_view.dart';
import 'admin_catalog_view.dart';
import 'admin_promotions_view.dart';
import 'admin_inventory_view.dart';
import 'admin_procurement_view.dart';
import 'admin_notifications_view.dart';
import 'admin_audit_log_view.dart';
import 'admin_invoices_view.dart';
import 'admin_notification_templates_view.dart';
import 'admin_settings_view.dart';

class AdminMainView extends StatefulWidget {
  const AdminMainView({super.key});

  @override
  State<AdminMainView> createState() => _AdminMainViewState();
}

class _AdminMainViewState extends State<AdminMainView> {
  int _currentIndex = 0;
  final Set<int> _loadedIndexes = {0};

  void _selectIndex(int index) {
    setState(() {
      _currentIndex = index;
      _loadedIndexes.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSalesRep = auth.currentUser?.roleName == 'sales_rep';

    // Navigation items definition
    final List<_NavItem> navItems = [
      _NavItem(icon: Icons.analytics_rounded, label: context.tr('dashboard')),
      _NavItem(icon: Icons.pie_chart_rounded, label: 'Metrics'),
      _NavItem(icon: Icons.query_stats_rounded, label: context.tr('reports')),
      _NavItem(icon: Icons.assignment_rounded, label: context.tr('orders')),
      _NavItem(
        icon: Icons.how_to_reg_rounded,
        label: context.tr('registrations'),
      ),
      _NavItem(icon: Icons.groups_rounded, label: context.tr('crm')),
      _NavItem(icon: Icons.map_rounded, label: context.tr('dispatch')),
      _NavItem(
        icon: Icons.person_add_alt_1_rounded,
        label: context.tr('onboard_shop'),
      ),
      _NavItem(icon: Icons.people_rounded, label: context.tr('sales_reps')),
      _NavItem(icon: Icons.inventory_2_rounded, label: context.tr('catalog')),
      _NavItem(
        icon: Icons.local_offer_rounded,
        label: context.tr('promotions'),
      ),
      _NavItem(icon: Icons.warehouse_rounded, label: context.tr('inventory')),
      _NavItem(
        icon: Icons.shopping_cart_checkout_rounded,
        label: context.tr('procurement'),
      ),
      _NavItem(
        icon: Icons.notifications_rounded,
        label: context.tr('notifications'),
      ),
      _NavItem(icon: Icons.receipt_long_rounded, label: context.tr('invoices')),
      _NavItem(icon: Icons.history_rounded, label: context.tr('audit_log')),
      _NavItem(icon: Icons.edit_notifications_rounded, label: 'Templates'),
      _NavItem(icon: Icons.settings_rounded, label: context.tr('settings')),
    ];

    final List<Widget> views = [
      DashboardView(
        onTabSelected: (index) {
          _selectIndex(index);
        },
      ),
      const AdminMetricsView(),
      const AdminReportsView(),
      const AdminOrdersView(),
      const AdminRegistrationsView(),
      const AdminCrmView(),
      const DispatchMapView(),
      const _AdminOnboardRetailerTab(),
      const SalesRepPerformanceView(),
      const AdminCatalogView(),
      const AdminPromotionsView(),
      const AdminInventoryView(),
      const AdminProcurementView(),
      const AdminNotificationsView(),
      const AdminInvoicesView(),
      const AdminAuditLogView(),
      const AdminNotificationTemplatesView(),
      const AdminSettingsView(),
    ];

    return AppBackGuard(
      isAtRoot: _currentIndex == 0,
      onBackToRoot: () => setState(() => _currentIndex = 0),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.badge_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  navItems[_currentIndex].label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                _selectIndex(13);
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.tr('sign_out')),
                    content: Text(context.tr('sign_out_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.tr('cancel')),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          auth.logout();
                        },
                        child: Text(
                          context.tr('sign_out'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              // Drawer Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        isSalesRep
                            ? Icons.badge_rounded
                            : Icons.admin_panel_settings,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.currentUser?.username ?? 'Admin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSalesRep
                          ? 'Sales Representative'
                          : auth.currentUser?.email ?? 'admin@bmp.com',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        context.tr('main').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...navItems
                        .sublist(0, 8)
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildDrawerItem(entry.key, entry.value),
                        ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        context.tr('management').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...navItems
                        .sublist(8, 12)
                        .asMap()
                        .entries
                        .map(
                          (entry) =>
                              _buildDrawerItem(entry.key + 8, entry.value),
                        ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        context.tr('system').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...navItems
                        .sublist(12)
                        .asMap()
                        .entries
                        .map(
                          (entry) =>
                              _buildDrawerItem(entry.key + 12, entry.value),
                        ),
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Halawat v1.0.0',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            views.length,
            (index) => _loadedIndexes.contains(index)
                ? views[index]
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, _NavItem item) {
    final bool isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        size: 22,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {
        _selectIndex(index);
        Navigator.of(context).pop(); // Close drawer
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// --- Embedded Onboarding Form Tab for Admin Panel ---

class _AdminOnboardRetailerTab extends StatefulWidget {
  const _AdminOnboardRetailerTab();

  @override
  State<_AdminOnboardRetailerTab> createState() =>
      _AdminOnboardRetailerTabState();
}

class _AdminOnboardRetailerTabState extends State<_AdminOnboardRetailerTab> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default referral code to the logged-in admin/rep's code if available
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.referralCode != null) {
      _referralController.text = auth.currentUser!.referralCode!;
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.onboardRetailer(
      shopName: _shopNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      referralCode: _referralController.text.trim().isEmpty
          ? null
          : _referralController.text.trim(),
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

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retailer successfully registered on the platform!'),
          backgroundColor: AppColors.secondary,
        ),
      );
      _shopNameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _addressController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      // Keep referral code
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Onboarding failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Onboard Retailer',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              const Text(
                'Register and link a new retail store to the BMP platform',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _shopNameController,
                          decoration: const InputDecoration(
                            labelText: 'Shop Name',
                            prefixIcon: Icon(
                              Icons.storefront,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Enter shop name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'e.g. 0612345678',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) =>
                              val == null || val.trim().length < 8
                              ? 'Enter a valid phone number'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) => val == null || !val.contains('@')
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) => val == null || val.length < 8
                              ? 'Password must be 8+ characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _referralController,
                          decoration: const InputDecoration(
                            labelText: 'Referral Code (Sales Rep Link)',
                            prefixIcon: Icon(
                              Icons.card_membership,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LocationPickerFields(
                          addressController: _addressController,
                          latitudeController: _latitudeController,
                          longitudeController: _longitudeController,
                          addressLabel: 'Retailer Address',
                        ),
                        const SizedBox(height: 24),
                        auth.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: _submit,
                                child: const Text('Onboard Shop'),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
