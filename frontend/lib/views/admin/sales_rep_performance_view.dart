import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/admin_provider.dart';
import '../shared/location_picker_fields.dart';
import 'admin_password_reset_dialog.dart';

class SalesRepPerformanceView extends StatefulWidget {
  const SalesRepPerformanceView({super.key});

  @override
  State<SalesRepPerformanceView> createState() =>
      _SalesRepPerformanceViewState();
}

class _SalesRepPerformanceViewState extends State<SalesRepPerformanceView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<AdminProvider>(context, listen: false).fetchSalesReps();
    });
  }

  void _showCreateRepDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'sales_rep';
    bool dialogLoading = false;
    bool canCollectCash = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final adminProvider = Provider.of<AdminProvider>(
              context,
              listen: false,
            );
            return AlertDialog(
              title: Text(context.tr('create_user_account')),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: context.tr('user_role'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(context.tr('role_admin')),
                          ),
                          DropdownMenuItem(
                            value: 'sales_rep',
                            child: Text(context.tr('role_sales_rep')),
                          ),
                          DropdownMenuItem(
                            value: 'distributor',
                            child: Text(context.tr('role_distributor')),
                          ),
                          DropdownMenuItem(
                            value: 'retailer',
                            child: Text(context.tr('role_retailer')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                              canCollectCash =
                                  val == 'distributor' ||
                                      val == 'sales_rep' ||
                                      val == 'admin'
                                  ? canCollectCash
                                  : false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: context.tr('full_name'),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? context.tr('error_full_name')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Please enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.length < 8
                            ? 'Password must be 8+ characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      LocationPickerFields(
                        addressController: addressController,
                        latitudeController: latitudeController,
                        longitudeController: longitudeController,
                        addressLabel: 'Address',
                      ),
                      if (selectedRole == 'distributor' ||
                          selectedRole == 'sales_rep' ||
                          selectedRole == 'admin') ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: canCollectCash,
                          onChanged: (value) {
                            setDialogState(() => canCollectCash = value);
                          },
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Can collect cash'),
                          subtitle: const Text(
                            'Allows this user to record cash collected from customers.',
                          ),
                          secondary: const Icon(
                            Icons.payments_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                dialogLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            dialogLoading = true;
                          });

                          final success = await adminProvider.createUserAccount(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            phone: phoneController.text.trim(),
                            role: selectedRole,
                            address: addressController.text.trim().isEmpty
                                ? null
                                : addressController.text.trim(),
                            latitude: latitudeController.text.trim().isEmpty
                                ? null
                                : double.parse(latitudeController.text.trim()),
                            longitude: longitudeController.text.trim().isEmpty
                                ? null
                                : double.parse(longitudeController.text.trim()),
                            canCollectCash: canCollectCash,
                          );

                          if (!mounted) return;

                          setDialogState(() {
                            dialogLoading = false;
                          });

                          if (success) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${context.tr(selectedRole == "sales_rep" ? "role_sales_rep" : selectedRole)} ${context.tr("added_success")}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            adminProvider.fetchSalesReps();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  adminProvider.error ??
                                      context.tr('save_failed'),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        child: Text(context.tr('create')),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('sales_representatives'),
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('sales_representatives_subtitle'),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: admin.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount:
                          admin.salesReps.length +
                          1 +
                          (admin.salesReps.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (admin.salesReps.isEmpty && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                context.tr('no_cash_collectors_msg'),
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          );
                        }

                        final cashSectionIndex =
                            admin.salesReps.length +
                            (admin.salesReps.isEmpty ? 1 : 0);
                        if (index == cashSectionIndex) {
                          return _buildCashCollectionSection(context, admin);
                        }

                        final rep = admin.salesReps[index];
                        return _buildRepPerformanceCard(
                          context,
                          rep,
                          index + 1,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRepDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
    );
  }

  Widget _buildRepPerformanceCard(BuildContext context, User rep, int rank) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final countedOrders = admin.countedOrdersForRep(rep);
    final assignedRetailers = admin.retailersForRep(rep);
    final double target = 100000.00;
    final double sales =
        rep.salesPerformance ??
        countedOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
    final double progress = (sales / target).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: rank == 1
                  ? AppColors.accent
                  : rank == 2
                  ? Colors.grey[300]
                  : Colors.orange[200],
              radius: 16,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank == 1
                      ? Colors.white
                      : rank == 2
                      ? AppColors.textPrimary
                      : Colors.orange[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rep.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context
                        .tr('referral_label')
                        .replaceFirst('{code}', rep.referralCode ?? "N/A"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${sales.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 15,
                  ),
                ),
                Text(
                  context.tr('counted_sales'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _RepStatPill(
                icon: Icons.storefront_rounded,
                label: context.tr('retailers'),
                value:
                    '${rep.assignedRetailerCount ?? assignedRetailers.length}',
              ),
              const SizedBox(width: 8),
              _RepStatPill(
                icon: Icons.receipt_long_rounded,
                label: context.tr('counted_orders'),
                value: '${rep.salesOrderCount ?? countedOrders.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('target_progress'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}% of ${target.toStringAsFixed(0)} DH',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 0.9 ? Colors.green : AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFeatureToggles(context, rep),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () =>
                  showAdminPasswordResetDialog(context: context, user: rep),
              icon: const Icon(Icons.lock_reset_rounded),
              label: Text(context.tr('reset_password')),
            ),
          ),
          const SizedBox(height: 16),
          _buildCountedSalesSection(countedOrders),
        ],
      ),
    );
  }

  Widget _buildFeatureToggles(BuildContext context, User rep) {
    final admin = Provider.of<AdminProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('rep_features'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        _FeatureSwitch(
          label: context.tr('feature_dashboard'),
          icon: Icons.space_dashboard_rounded,
          value: rep.featureEnabled('dashboard'),
          onChanged: (value) =>
              _updateRepFeature(context, admin, rep, 'dashboard', value),
        ),
        _FeatureSwitch(
          label: context.tr('feature_retailers'),
          icon: Icons.storefront_rounded,
          value: rep.featureEnabled('retailers'),
          onChanged: (value) =>
              _updateRepFeature(context, admin, rep, 'retailers', value),
        ),
        _FeatureSwitch(
          label: context.tr('feature_orders'),
          icon: Icons.receipt_long_rounded,
          value: rep.featureEnabled('orders'),
          onChanged: (value) =>
              _updateRepFeature(context, admin, rep, 'orders', value),
        ),
        _FeatureSwitch(
          label: context.tr('feature_onboarding'),
          icon: Icons.person_add_alt_1_rounded,
          value: rep.featureEnabled('onboarding'),
          onChanged: (value) =>
              _updateRepFeature(context, admin, rep, 'onboarding', value),
        ),
      ],
    );
  }

  Future<void> _updateRepFeature(
    BuildContext context,
    AdminProvider admin,
    User rep,
    String key,
    bool value,
  ) async {
    final features = Map<String, bool>.from(rep.representativeFeatures);
    features[key] = value;
    final success = await admin.updateRepresentativeFeatures(rep, features);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${rep.username} feature updated.'
              : admin.error ?? 'Unable to update representative feature.',
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }

  Widget _buildCountedSalesSection(List<Order> countedOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('sales_counted_rep'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (countedOrders.isEmpty)
          Text(
            context.tr('no_counted_orders_msg'),
            style: const TextStyle(color: AppColors.textLight),
          )
        else
          ...countedOrders.take(6).map((order) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              title: Text(order.orderNumber ?? order.id),
              subtitle: Text('${order.retailerName} - ${order.status.name}'),
              trailing: Text(
                '${order.totalAmount.toStringAsFixed(2)} DH',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCashCollectionSection(
    BuildContext context,
    AdminProvider admin,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  context.tr('cash_collection_access'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('cash_collection_access_desc'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            if (admin.cashCollectors.isEmpty)
              Text(
                context.tr('no_cash_collectors_msg'),
                style: const TextStyle(color: AppColors.textLight),
              )
            else
              ...admin.cashCollectors.map((user) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              user.roleName == 'distributor'
                                  ? Icons.local_shipping_rounded
                                  : Icons.supervisor_account_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.tr(user.roleName == "distributor" ? "role_distributor" : user.roleName)} - ${user.email}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.tr('reset_password'),
                            onPressed: () => showAdminPasswordResetDialog(
                              context: context,
                              user: user,
                            ),
                            icon: const Icon(Icons.lock_reset_rounded),
                          ),
                          Switch(
                            value: user.canCollectCash,
                            onChanged: (enabled) async {
                              final success = await admin
                                  .updateCashCollectionPermission(
                                    user,
                                    enabled,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '${context.tr("cash_collection_access")} ${enabled ? context.tr("active") : context.tr("inactive")} ${user.username}'
                                        : admin.error ?? 'Error',
                                  ),
                                  backgroundColor: success
                                      ? AppColors.secondary
                                      : AppColors.error,
                                ),
                              );
                            },
                            activeColor: AppColors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RepStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RepStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

class _FeatureSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeatureSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
