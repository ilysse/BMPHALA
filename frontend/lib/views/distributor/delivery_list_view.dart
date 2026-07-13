import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/delivery.dart';
import 'delivery_detail_view.dart';

class DeliveryListView extends StatefulWidget {
  const DeliveryListView({super.key});

  @override
  State<DeliveryListView> createState() => _DeliveryListViewState();
}

class _DeliveryListViewState extends State<DeliveryListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<DeliveryProvider>(
          context,
          listen: false,
        ).fetchTasks(auth.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delivery = Provider.of<DeliveryProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('my_deliveries')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          tabs: [
            Tab(
              text:
                  '${context.tr('status_pending')} (${delivery.pendingTasks.length})',
            ),
            Tab(
              text: '${context.tr('active')} (${delivery.activeTasks.length})',
            ),
            Tab(
              text:
                  '${context.tr('status_delivered')} (${delivery.completedTasks.length})',
            ),
          ],
        ),
      ),
      body: delivery.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(context, delivery.pendingTasks),
                _buildTaskList(context, delivery.activeTasks),
                _buildTaskList(context, delivery.completedTasks),
              ],
            ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<DeliveryTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_deliveries_section'),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final hasPin = task.latitude != 0.0 && task.longitude != 0.0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeliveryDetailView(task: task),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${context.tr('task_label')}: ${task.order.orderNumber ?? task.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(task.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.order.retailerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.order.items.isEmpty
                              ? context.tr('no_order_items')
                              : task.order.items
                                    .map(
                                      (item) =>
                                          '${item.quantity}x ${item.product.name}',
                                    )
                                    .join('  |  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.order.deliveryAddress ??
                              context.tr('no_delivery_address'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasPin
                            ? Icons.location_on_rounded
                            : Icons.wrong_location_rounded,
                        size: 18,
                        color: hasPin ? AppColors.secondary : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasPin
                            ? context.tr('delivery_pin_saved')
                            : context.tr('delivery_pin_missing'),
                        style: TextStyle(
                          fontSize: 13,
                          color: hasPin ? AppColors.secondary : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${context.tr('value')}: ${task.order.totalAmount.toStringAsFixed(2)} DH',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            context.tr('details'),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(DeliveryStatus status) {
    Color color;
    String text;

    switch (status) {
      case DeliveryStatus.pending:
        color = AppColors.accent;
        text = context.tr('status_pending');
        break;
      case DeliveryStatus.inTransit:
        color = AppColors.primaryLight;
        text = context.tr('status_in_transit');
        break;
      case DeliveryStatus.completed:
        color = Colors.green;
        text = context.tr('status_delivered');
        break;
      case DeliveryStatus.failed:
        color = AppColors.error;
        text = context.tr('status_failed');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
