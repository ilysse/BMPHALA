import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/admin_provider.dart';

class DashboardView extends StatefulWidget {
  final Function(int)? onTabSelected;
  const DashboardView({super.key, this.onTabSelected});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<AdminProvider>(
        context,
        listen: false,
      ).fetchDashboardMetrics();
    });
  }

  void _showUnpaidBalanceDialog(BuildContext context, AdminProvider admin) {
    final unpaidOrders = admin.allOrders
        .where((o) => o.remainingBalance > 0)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('outstanding_balances_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${admin.outstandingPayments.toStringAsFixed(2)} DH',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('total_outstanding_awaiting'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 24),
              SizedBox(
                height: 300,
                child: unpaidOrders.isEmpty
                    ? Center(child: Text(context.tr('no_outstanding_payments')))
                    : ListView.builder(
                        itemCount: unpaidOrders.length,
                        itemBuilder: (context, index) {
                          final o = unpaidOrders[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(o.retailerName),
                            subtitle: Text(
                              o.orderNumber ?? 'Order #${o.id.substring(0, 5)}',
                            ),
                            trailing: Text(
                              '-${o.remainingBalance.toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    if (admin.isDashboardLoading && admin.allOrders.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: _DashboardSkeleton()),
      );
    }

    if (admin.error != null && admin.allOrders.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(admin.error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => admin.fetchDashboardMetrics(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('refresh')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => admin.fetchDashboardMetrics(force: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('dashboard'),
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 16),

                // Metric Cards Grid
                _buildMetricsGrid(admin),
                const SizedBox(height: 24),

                // Sales Chart Card
                _buildSalesChartCard(admin),
                const SizedBox(height: 24),

                // Recent Activity
                _buildRecentActivitySection(admin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(AdminProvider admin) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: context.tr('total_revenue'),
                value: '${admin.totalSales.toStringAsFixed(0)} DH',
                color: AppColors.primary,
                icon: Icons.payments_outlined,
                subtitle: context.tr('open_reports'),
                onTap: () => widget.onTabSelected?.call(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: context.tr('active_shops'),
                value: '${admin.activeRetailersCount}',
                color: AppColors.secondary,
                icon: Icons.storefront,
                subtitle: context.tr('onboard_shop'),
                onTap: () =>
                    widget.onTabSelected?.call(7), // Switch to Onboard Shop
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: context.tr('orders'),
                value: '${admin.totalOrdersCount}',
                color: AppColors.accent,
                icon: Icons.assignment_outlined,
                subtitle: context.tr('view_all_orders'),
                onTap: () => widget.onTabSelected?.call(3), // Switch to Orders
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                title: context.tr('unpaid_balance'),
                value: '${admin.outstandingPayments.toStringAsFixed(0)} DH',
                color: AppColors.error,
                icon: Icons.account_balance_wallet_outlined,
                subtitle: context.tr('click_view_lists'),
                onTap: () => _showUnpaidBalanceDialog(context, admin),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(Icons.more_horiz, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChartCard(AdminProvider admin) {
    final trend = admin.salesTrend;
    final spots = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      final double val = (trend[i]['sales'] ?? trend[i]['amount'] ?? 0.0)
          .toDouble();
      spots.add(FlSpot(i.toDouble(), val));
    }
    final double maxY = spots.isEmpty
        ? 1.0
        : spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('sales_performance_trend'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('revenue_analytics_subtitle'),
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? Center(child: Text(context.tr('no_sales_period')))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < trend.length) {
                                  final String date =
                                      '${trend[index]['date'] ?? trend[index]['label'] ?? ''}';
                                  final displayDate = date.length >= 10
                                      ? date.substring(5)
                                      : date;
                                  return Text(
                                    displayDate,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 22,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value / 1000).toStringAsFixed(0)}k DH',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                              reservedSize: 32,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: spots.isEmpty
                            ? 5.0
                            : (spots.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY <= 0 ? 1 : maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(AdminProvider admin) {
    final recentOrders = admin.allOrders.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final top3 = recentOrders.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('recent_system_activity') == 'recent_system_activity'
                  ? 'Recent System Activity'
                  : context.tr('recent_system_activity'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (top3.isEmpty)
              Text(
                context.tr('no_recent_activity') == 'no_recent_activity'
                    ? 'No recent activity'
                    : context.tr('no_recent_activity'),
              )
            else
              ...top3.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final isLast = index == top3.length - 1;

                final timeDiff = DateTime.now().difference(order.createdAt);
                String timeStr = '';
                if (timeDiff.inDays > 0) {
                  timeStr = '${timeDiff.inDays}d ago';
                } else if (timeDiff.inHours > 0) {
                  timeStr = '${timeDiff.inHours}h ago';
                } else {
                  timeStr = '${timeDiff.inMinutes}m ago';
                }

                return Column(
                  children: [
                    _buildActivityItem(
                      icon: Icons.add_shopping_cart,
                      color: AppColors.primary,
                      title:
                          context
                                  .tr('order_placed_title')
                                  .replaceAll(
                                    '{order}',
                                    order.orderNumber ??
                                        order.id.substring(0, 5),
                                  ) ==
                              'order_placed_title'
                          ? 'Order ${order.orderNumber ?? order.id.substring(0, 5)} Placed'
                          : context
                                .tr('order_placed_title')
                                .replaceAll(
                                  '{order}',
                                  order.orderNumber ?? order.id.substring(0, 5),
                                ),
                      time: timeStr,
                      description:
                          context
                                  .tr('placed_by_desc')
                                  .replaceAll('{retailer}', order.retailerName)
                                  .replaceAll(
                                    '{amount}',
                                    order.totalAmount.toStringAsFixed(2),
                                  ) ==
                              'placed_by_desc'
                          ? 'Placed by ${order.retailerName} for ${order.totalAmount.toStringAsFixed(2)} DH'
                          : context
                                .tr('placed_by_desc')
                                .replaceAll('{retailer}', order.retailerName)
                                .replaceAll(
                                  '{amount}',
                                  order.totalAmount.toStringAsFixed(2),
                                ),
                    ),
                    if (!isLast) const Divider(height: 24),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 18,
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(width: 140, height: 28, color: Colors.black12),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (_, __) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black12,
                  ),
                  const Spacer(),
                  Container(width: 80, height: 20, color: Colors.black12),
                  const SizedBox(height: 8),
                  Container(width: 110, height: 12, color: Colors.black12),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
