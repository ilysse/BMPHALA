import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/order_provider.dart';
import '../../models/order.dart';
import '../../core/localization/app_localizations.dart';

class PaymentsView extends StatelessWidget {
  const PaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    // Calculate overall financial metrics
    double totalSpent = 0.0;
    double totalPaid = 0.0;

    for (var order in orderProvider.orders) {
      if (order.status != OrderStatus.cancelled) {
        totalSpent += order.totalAmount;
        totalPaid += order.paidAmount;
      }
    }

    double outstanding = totalSpent - totalPaid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.tr('cash_balance_outstanding'))),
      body: Column(
        children: [
          // Financial Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: context.tr('total_ordered'),
                    value: '${totalSpent.toStringAsFixed(2)} DH',
                    color: AppColors.primary,
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: context.tr('outstanding'),
                    value: '${outstanding.toStringAsFixed(2)} DH',
                    color: outstanding > 0 ? AppColors.accent : Colors.green,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
          ),

          // Payment List Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Text(
                  context.tr('cash_collection_status'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Payments List
          Expanded(
            child: orderProvider.orders.isEmpty
                ? Center(
                    child: Text(
                      context.tr('no_payment_transactions'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orderProvider.orders.length,
                    itemBuilder: (context, index) {
                      final order = orderProvider.orders[index];
                      return _buildPaymentListItem(context, order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentListItem(BuildContext context, Order order) {
    Color statusColor;
    String statusText;

    switch (order.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        statusText = context.tr('paid');
        break;
      case PaymentStatus.partiallyPaid:
        statusColor = AppColors.accent;
        statusText = context.tr('payment_partially_paid');
        break;
      case PaymentStatus.unpaid:
        statusColor = AppColors.error;
        statusText = context.tr('unpaid');
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('order_label')}: ${order.orderNumber ?? order.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('outstanding')}: ${order.remainingBalance.toStringAsFixed(2)} DH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: order.remainingBalance > 0
                              ? AppColors.textSecondary
                              : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('collected')}: ${order.paidAmount.toStringAsFixed(2)} / ${order.totalAmount.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (order.paymentStatus != PaymentStatus.paid &&
                    order.status != OrderStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      context.tr('cash_collected_by_responsible'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
