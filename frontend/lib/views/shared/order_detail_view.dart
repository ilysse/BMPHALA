import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';
import '../../models/order.dart';

class OrderDetailView extends StatelessWidget {
  final Order order;

  const OrderDetailView({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final showTabs = order.status == OrderStatus.delivered;

    if (showTabs) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              '${context.tr('order_label')} ${order.orderNumber ?? order.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            centerTitle: true,
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: const Icon(Icons.assignment_outlined),
                  text: context.tr('details'),
                ),
                Tab(
                  icon: const Icon(Icons.verified_outlined),
                  text: context.tr('delivery_proof_tab'),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(context),
                    const SizedBox(height: 20),
                    _buildTrackingStepper(context),
                    const SizedBox(height: 20),
                    _buildClientInfoCard(context),
                    const SizedBox(height: 16),
                    _buildDistributorInfoCard(context),
                    const SizedBox(height: 16),
                    _buildItemsTable(context),
                    const SizedBox(height: 16),
                    _buildPaymentSummaryCard(context),
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildNotesSection(context),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeliveryProofSection(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${context.tr('order_label')} ${order.orderNumber ?? order.id.substring(0, 8).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(context),
            const SizedBox(height: 20),
            _buildTrackingStepper(context),
            const SizedBox(height: 20),
            _buildClientInfoCard(context),
            const SizedBox(height: 16),
            _buildDistributorInfoCard(context),
            const SizedBox(height: 16),
            _buildItemsTable(context),
            const SizedBox(height: 16),
            _buildPaymentSummaryCard(context),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesSection(context),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── HEADER SECTION ──────────────────────────────────────────────────

  Widget _buildHeaderSection(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber ??
                        '#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _buildStatusBadge(context, order.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(order.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildPaymentStatusBadge(context, order.paymentStatus),
              ],
            ),
            if (order.expectedDeliveryAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.tr('scheduled_delivery')}: ${_formatDate(order.expectedDeliveryAt!.toLocal())}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, OrderStatus status) {
    final config = _orderStatusConfig(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 5),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBadge(BuildContext context, PaymentStatus status) {
    final config = _paymentStatusConfig(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ─── VISUAL TRACKING STEPPER ─────────────────────────────────────────

  Widget _buildTrackingStepper(BuildContext context) {
    final int currentStep = _resolveCurrentStep(order.status);
    final steps = [
      _StepData(
        icon: Icons.hourglass_top_rounded,
        label: context.tr('status_pending'),
      ),
      _StepData(
        icon: Icons.thumb_up_alt_rounded,
        label: context.tr('status_approved'),
      ),
      _StepData(
        icon: Icons.local_shipping_rounded,
        label: context.tr('status_in_transit'),
      ),
      _StepData(
        icon: Icons.check_circle_rounded,
        label: context.tr('status_delivered'),
      ),
    ];

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final lineIndex = index ~/ 2;
              final isCompleted = lineIndex < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex <= currentStep;
            final isCurrent = stepIndex == currentStep;
            final step = steps[stepIndex];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 44 : 38,
                  height: isCurrent ? 44 : 38,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : step.icon,
                    color: isCompleted ? Colors.white : Colors.grey.shade500,
                    size: isCurrent ? 22 : 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCompleted
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  int _resolveCurrentStep(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.approved:
        return 1;
      case OrderStatus.outForDelivery:
        return 2;
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  // ─── CLIENT INFO CARD ────────────────────────────────────────────────

  Widget _buildClientInfoCard(BuildContext context) {
    return _buildSectionCard(
      icon: Icons.storefront_rounded,
      title: context.tr('client_information'),
      children: [
        _buildInfoRow(
          Icons.person_rounded,
          context.tr('retailer'),
          order.retailerName,
        ),
        if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
          _buildInfoRow(
            Icons.location_on_rounded,
            context.tr('address'),
            order.deliveryAddress!,
          ),
        if (order.deliveryLatitude != null && order.deliveryLongitude != null)
          _buildInfoRow(
            Icons.my_location_rounded,
            context.tr('coordinates'),
            '${order.deliveryLatitude!.toStringAsFixed(5)}, ${order.deliveryLongitude!.toStringAsFixed(5)}',
          ),
      ],
    );
  }

  // ─── DISTRIBUTOR INFO CARD ───────────────────────────────────────────

  Widget _buildDistributorInfoCard(BuildContext context) {
    final hasDistributor =
        order.assignedDistributorName != null &&
        order.assignedDistributorName!.isNotEmpty;

    return _buildSectionCard(
      icon: Icons.local_shipping_outlined,
      title: context.tr('distributor'),
      children: [
        _buildInfoRow(
          hasDistributor ? Icons.person_rounded : Icons.hourglass_empty_rounded,
          context.tr('assigned_to'),
          hasDistributor
              ? order.assignedDistributorName!
              : context.tr('awaiting_assignment'),
          valueColor: hasDistributor ? null : AppColors.textSecondary,
          valueStyle: hasDistributor ? null : FontStyle.italic,
        ),
      ],
    );
  }

  // ─── ITEMS TABLE ─────────────────────────────────────────────────────

  Widget _buildItemsTable(BuildContext context) {
    final itemText = order.items.length == 1
        ? context.tr('item')
        : context.tr('items');
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('order_items'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${order.items.length} $itemText',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 520
                    ? _buildCompactItemsList(context)
                    : Table(
                        columnWidths: const {
                          0: FixedColumnWidth(36),
                          1: FlexColumnWidth(3),
                          2: FixedColumnWidth(44),
                          3: FlexColumnWidth(2),
                          4: FlexColumnWidth(2),
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                            ),
                            children: [
                              _tableHeaderCell('#'),
                              _tableHeaderCell(context.tr('product')),
                              _tableHeaderCell(context.tr('qty')),
                              _tableHeaderCell(context.tr('unit_price')),
                              _tableHeaderCell(context.tr('total')),
                            ],
                          ),
                          // Data rows
                          ...List.generate(order.items.length, (index) {
                            final item = order.items[index];
                            final isEven = index.isEven;
                            return TableRow(
                              decoration: BoxDecoration(
                                color: isEven
                                    ? Colors.white
                                    : Colors.grey.shade50,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              children: [
                                _tableDataCell('${index + 1}', center: true),
                                _tableDataCell(item.product.name, bold: true),
                                _tableDataCell(
                                  '${item.quantity}',
                                  center: true,
                                ),
                                _tableDataCell(
                                  '${item.product.price.toStringAsFixed(2)} DH',
                                ),
                                _tableDataCell(
                                  '${item.totalPrice.toStringAsFixed(2)} DH',
                                  bold: true,
                                  color: AppColors.primary,
                                ),
                              ],
                            );
                          }),
                          // Grand total row
                          TableRow(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            children: [
                              const SizedBox(height: 44),
                              const SizedBox(),
                              const SizedBox(),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                child: Text(
                                  context.tr('total').toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                child: Text(
                                  '${order.totalAmount.toStringAsFixed(2)} DH',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildCompactItemsList(BuildContext context) {
    return Column(
      children: [
        ...order.items.asMap().entries.map((entry) {
          final item = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: entry.key.isEven ? Colors.white : Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${entry.key + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.quantity} x ${item.product.price.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.totalPrice.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${context.tr('total')}: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${order.totalAmount.toStringAsFixed(2)} DH',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _tableDataCell(
    String text, {
    bool bold = false,
    bool center = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? AppColors.textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── PAYMENT SUMMARY CARD ────────────────────────────────────────────

  Widget _buildPaymentSummaryCard(BuildContext context) {
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_rounded,
      title: context.tr('payment_summary'),
      children: [
        _buildPaymentRow(
          context.tr('total_amount'),
          '${order.totalAmount.toStringAsFixed(2)} DH',
          valueColor: AppColors.textPrimary,
          isBold: true,
        ),
        const Divider(height: 20),
        _buildPaymentRow(
          context.tr('paid'),
          '${order.paidAmount.toStringAsFixed(2)} DH',
          valueColor: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 8),
        _buildPaymentRow(
          context.tr('remaining_balance'),
          '${order.remainingBalance.toStringAsFixed(2)} DH',
          valueColor: order.remainingBalance > 0
              ? AppColors.error
              : const Color(0xFF2E7D32),
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildPaymentRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── DELIVERY PROOF SECTION ──────────────────────────────────────────

  Widget _buildDeliveryProofSection(BuildContext context) {
    final hasPhoto =
        order.deliveryPhotoUrl != null && order.deliveryPhotoUrl!.isNotEmpty;
    final hasSignature =
        order.deliverySignatureUrl != null &&
        order.deliverySignatureUrl!.isNotEmpty;

    return _buildSectionCard(
      icon: Icons.verified_rounded,
      title: context.tr('delivery_proof'),
      children: [
        if (!hasPhoto && !hasSignature)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('no_delivery_proof'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        if (hasPhoto) ...[
          Text(
            context.tr('delivery_photo'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: ApiService.publicImageUrl(order.deliveryPhotoUrl!),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              memCacheWidth: 600,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.secondary,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('failed_load_image'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (hasSignature) ...[
          Text(
            context.tr('delivery_signature'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ApiService.publicImageUrl(
                  order.deliverySignatureUrl!,
                ),
                height: 120,
                fit: BoxFit.contain,
                memCacheHeight: 240,
                placeholder: (context, url) => const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('failed_load_signature'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── NOTES SECTION ───────────────────────────────────────────────────

  Widget _buildNotesSection(BuildContext context) {
    return _buildSectionCard(
      icon: Icons.sticky_note_2_rounded,
      title: context.tr('notes'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
          ),
          child: Text(
            order.notes!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ─── SHARED HELPERS ──────────────────────────────────────────────────

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    FontStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
                fontStyle: valueStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  _StatusConfig _orderStatusConfig(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return _StatusConfig(
          label: context.tr('status_pending'),
          color: const Color(0xFFE67E22),
          icon: Icons.hourglass_top_rounded,
        );
      case OrderStatus.approved:
        return _StatusConfig(
          label: context.tr('status_approved'),
          color: const Color(0xFF2196F3),
          icon: Icons.thumb_up_alt_rounded,
        );
      case OrderStatus.outForDelivery:
        return _StatusConfig(
          label: context.tr('status_in_transit'),
          color: const Color(0xFF9C27B0),
          icon: Icons.local_shipping_rounded,
        );
      case OrderStatus.delivered:
        return _StatusConfig(
          label: context.tr('status_delivered'),
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.cancelled:
        return _StatusConfig(
          label: context.tr('status_cancelled'),
          color: AppColors.error,
          icon: Icons.cancel_rounded,
        );
    }
  }

  _StatusConfig _paymentStatusConfig(
    BuildContext context,
    PaymentStatus status,
  ) {
    switch (status) {
      case PaymentStatus.unpaid:
        return _StatusConfig(
          label: context.tr('payment_unpaid'),
          color: AppColors.error,
          icon: Icons.money_off_rounded,
        );
      case PaymentStatus.partiallyPaid:
        return _StatusConfig(
          label: context.tr('payment_partially_paid'),
          color: const Color(0xFFE67E22),
          icon: Icons.payments_rounded,
        );
      case PaymentStatus.paid:
        return _StatusConfig(
          label: context.tr('payment_paid'),
          color: const Color(0xFF2E7D32),
          icon: Icons.paid_rounded,
        );
    }
  }
}

// ─── PRIVATE DATA CLASSES ────────────────────────────────────────────────

class _StatusConfig {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _StepData {
  final IconData icon;
  final String label;

  const _StepData({required this.icon, required this.label});
}
