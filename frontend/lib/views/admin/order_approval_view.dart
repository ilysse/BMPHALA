import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/admin_provider.dart';
import '../../models/order.dart';
import '../../models/user.dart';

class OrderApprovalView extends StatefulWidget {
  const OrderApprovalView({super.key});

  @override
  State<OrderApprovalView> createState() => _OrderApprovalViewState();
}

class _OrderApprovalViewState extends State<OrderApprovalView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      provider.fetchPendingApprovals();
      provider.fetchDistributors();
    });
  }

  void _showAssignDialog(BuildContext context, Order order) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    User? selectedDistributor;

    if (admin.distributors.isNotEmpty) {
      selectedDistributor = admin.distributors.first;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Approve & Assign Carrier'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assigning order: ${order.id}'),
                  const SizedBox(height: 8),
                  Text(
                    'Retailer: ${order.retailerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Amount: ${order.totalAmount.toStringAsFixed(2)} DH',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Distributor:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  admin.distributors.isEmpty
                      ? const Text(
                          'No distributors found',
                          style: TextStyle(color: AppColors.error),
                        )
                      : DropdownButtonFormField<User>(
                          value: selectedDistributor,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: admin.distributors.map((dist) {
                            return DropdownMenuItem<User>(
                              value: dist,
                              child: Text(dist.username),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedDistributor = val;
                            });
                          },
                        ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: selectedDistributor == null
                      ? null
                      : () async {
                          final success = await admin.approveOrder(
                            order.id,
                            selectedDistributor!.id,
                            selectedDistributor!.username,
                          );
                          if (success && context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order ${order.id} approved and assigned to ${selectedDistributor!.username}!',
                                ),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          }
                        },
                  child: const Text('Confirm Assignment'),
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
              child: Text(
                'Order Approvals',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
            ),
            Expanded(
              child: admin.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : admin.pendingApprovals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending orders to approve',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: admin.pendingApprovals.length,
                      itemBuilder: (context, index) {
                        final order = admin.pendingApprovals[index];
                        return _buildOrderApprovalCard(context, order, admin);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderApprovalCard(
    BuildContext context,
    Order order,
    AdminProvider admin,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.retailerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${order.totalAmount.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.storefront,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  order.orderNumber ?? order.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 8),
                Text(
                  'Placed: ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')} today',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.tr('reject_order')),
                        content: Text('${context.tr('reject_order_confirm')} ${order.orderNumber ?? order.id}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(context.tr('cancel')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(context.tr('reject')),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      final success = await admin.rejectOrder(order.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${context.tr('order_rejected')} ${order.orderNumber ?? order.id}.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(admin.error ?? context.tr('failed_reject_order')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    context.tr('reject'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _showAssignDialog(context, order),
                  child: const Text('Approve & Assign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
