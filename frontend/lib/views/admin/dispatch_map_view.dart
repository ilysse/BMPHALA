import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';
import '../../core/utils/print_helper.dart';
import '../../core/utils/invoice_branding.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../shared/location_picker_fields.dart';
import '../shared/order_detail_view.dart';

class DispatchMapView extends StatefulWidget {
  const DispatchMapView({super.key});

  @override
  State<DispatchMapView> createState() => _DispatchMapViewState();
}

class _DispatchMapViewState extends State<DispatchMapView> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  List<Order> _orders = [];
  List<User> _distributors = [];
  List<User> _retailers = [];
  List<Order> _previewOrders = [];
  List<LatLng> _zonePoints = [];
  User? _selectedDistributor;
  bool _isLoading = true;
  bool _isDrawMode = false;
  bool _isPreviewing = false;
  bool _isDispatching = false;
  String? _error;
  double _previewTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadDispatchData();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadDispatchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        _apiService.client.get('/dispatch/orders'),
        _apiService.client.get('/users'),
      ]);

      final ordersData = responses[0].data['data'] as List<dynamic>? ?? [];
      final usersData = responses[1].data['data'] as List<dynamic>? ?? [];
      final allUsers = usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
      final distributors = allUsers
          .where((user) => user.role == UserRole.distributor)
          .toList();
      final retailers = allUsers
          .where((user) => user.role == UserRole.retailer)
          .toList();

      if (!mounted) return;
      setState(() {
        _orders = ordersData
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .where(
              (order) => _isValidLatLng(
                order.deliveryLatitude,
                order.deliveryLongitude,
              ),
            )
            .toList();
        _distributors = distributors;
        _retailers = retailers;
        final selectedDistributorId = _selectedDistributor?.id;
        _selectedDistributor = distributors
            .where((user) => user.id == selectedDistributorId)
            .cast<User?>()
            .firstWhere(
              (user) => user != null,
              orElse: () => distributors.isNotEmpty ? distributors.first : null,
            );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load dispatch data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _previewZone() async {
    if (_zonePoints.length < 3) {
      _showMessage('Draw at least three points to create a dispatch zone.');
      return;
    }

    setState(() {
      _isPreviewing = true;
      _error = null;
    });

    try {
      final response = await _apiService.client.post(
        '/dispatch/preview',
        data: {'zone_geojson': _zoneGeoJson()},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final ordersData = data['orders'] as List<dynamic>? ?? [];

      if (!mounted) return;
      setState(() {
        _previewOrders = ordersData
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
        _previewTotal = _toDouble(data['grand_total']);
        _isPreviewing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No matching orders found for this zone.';
        _previewOrders = [];
        _previewTotal = 0;
        _isPreviewing = false;
      });
    }
  }

  Future<void> _dispatchZone() async {
    if (_selectedDistributor == null) {
      _showMessage('Choose a distributor before dispatching.');
      return;
    }
    if (_zonePoints.length < 3) {
      _showMessage('Draw at least three points to create a dispatch zone.');
      return;
    }

    setState(() {
      _isDispatching = true;
      _error = null;
    });

    try {
      final response = await _apiService.client.post(
        '/dispatch/assign',
        data: {
          'distributor_id': _selectedDistributor!.id,
          'zone_geojson': _zoneGeoJson(),
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final assignedCount = data['assigned_count'] ?? 0;
      final dispatchedOrderIds =
          (data['order_ids'] as List<dynamic>?)?.cast<String>() ??
          _previewOrders.map((o) => o.id).toList();

      if (!mounted) return;
      _showMessage(
        'Dispatched $assignedCount orders to ${_selectedDistributor!.username}.',
      );

      // Offer bulk invoice printing for dispatched orders
      if (dispatchedOrderIds.isNotEmpty) {
        _offerBulkInvoicePrint(dispatchedOrderIds, assignedCount);
      }

      setState(() {
        _zonePoints = [];
        _previewOrders = [];
        _previewTotal = 0;
        _isDrawMode = false;
      });
      await _loadDispatchData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Dispatch failed. Preview the zone and try again.';
        _isDispatching = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDispatching = false;
        });
      }
    }
  }

  /// After dispatch, offer to auto-generate invoices and bulk-print them
  Future<void> _offerBulkInvoicePrint(List<String> orderIds, int count) async {
    if (!mounted) return;
    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.print_rounded,
          size: 40,
          color: AppColors.primary,
        ),
        title: const Text('Print Dispatch Invoices?'),
        content: Text(
          'Generate and print invoices for all $count dispatched orders?\n\nThis will create invoices for orders that don\'t have one yet, then open the bulk print view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Generate & Print'),
          ),
        ],
      ),
    );

    if (shouldPrint != true || !mounted) return;

    try {
      // Generate invoices for each dispatched order
      for (final orderId in orderIds) {
        try {
          // Try to generate an invoice (backend will skip if one already exists)
          await _apiService.client.post(
            '/invoices',
            data: {
              'order_id': orderId,
              'due_date': DateTime.now()
                  .add(const Duration(days: 14))
                  .toIso8601String()
                  .substring(0, 10),
            },
          );
        } catch (_) {
          // Invoice may already exist, that's fine
        }
      }

      // Fetch all invoices and filter to the dispatched orders
      final invoicesRes = await _apiService.client.get(
        '/invoices',
        queryParameters: {'per_page': 500},
      );
      final allInvoices = invoicesRes.data['data'] as List<dynamic>? ?? [];
      final dispatchInvoices = allInvoices.where((inv) {
        final invOrderId = inv['order_id'] ?? inv['order']?['id'];
        return orderIds.contains(invOrderId);
      }).toList();

      if (dispatchInvoices.isEmpty) {
        if (mounted) _showMessage('No invoices found for dispatched orders.');
        return;
      }

      // Build and print HTML
      final fallbackLogo = await loadDefaultInvoiceLogoDataUri();
      final htmlParts = dispatchInvoices
          .map((invoice) => _buildDispatchInvoiceHtml(invoice, fallbackLogo))
          .join();
      await printHtmlDocument(
        title:
            'Dispatch Invoices - ${DateTime.now().toIso8601String().substring(0, 10)}',
        bodyHtml: htmlParts,
      );

      if (mounted) {
        _showMessage(
          'Opened print view for ${dispatchInvoices.length} invoices.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Invoice printing failed: $e');
      }
    }
  }

  String _buildDispatchInvoiceHtml(dynamic invoice, String fallbackLogo) {
    final order = invoice['order'] as Map<String, dynamic>? ?? {};
    final company = invoice['company'] as Map<String, dynamic>? ?? {};
    final retailer = order['retailer'] as Map<String, dynamic>? ?? {};
    final items = order['items'] as List<dynamic>? ?? [];
    final invoiceNumber = htmlEscape.convert(
      '${invoice['invoice_number'] ?? 'Invoice'}',
    );
    final retailerName = htmlEscape.convert(
      '${retailer['name'] ?? retailer['username'] ?? 'Retailer'}',
    );
    final retailerAddress = htmlEscape.convert('${retailer['address'] ?? ''}');
    final retailerPhone = htmlEscape.convert(
      '${retailer['phone'] ?? retailer['email'] ?? ''}',
    );
    final orderNumber = htmlEscape.convert(
      '${order['order_number'] ?? order['id'] ?? ''}',
    );
    final createdDate =
        '${invoice['created_at'] ?? order['created_at'] ?? ''}'.length >= 10
        ? '${invoice['created_at'] ?? order['created_at'] ?? ''}'.substring(
            0,
            10,
          )
        : 'N/A';
    final dueDate = '${invoice['due_date'] ?? ''}'.length >= 10
        ? '${invoice['due_date'] ?? ''}'.substring(0, 10)
        : 'N/A';
    final status = htmlEscape.convert('${invoice['status'] ?? 'draft'}');
    final amountDue = _fmtMoney(
      invoice['amount_due'] ?? invoice['amount'] ?? 0,
    );
    final companyName = htmlEscape.convert(
      '${company['name'] ?? 'Halawat Lil Moaamalat'}',
    );
    final companyAddress = htmlEscape.convert(
      '${company['address'] ?? 'Casablanca, Morocco'}',
    );
    final companyContact = htmlEscape.convert(
      '${company['phone'] ?? company['email'] ?? ''}',
    );
    final logoUrl = htmlEscape.convert(
      '${company['logo_url'] ?? fallbackLogo}',
    );

    double subtotal = 0;
    int rowIdx = 0;
    final itemRows = items.isEmpty
        ? '<tr><td colspan="5" style="text-align:center;color:#6b7280;">No line items.</td></tr>'
        : items.map((item) {
            rowIdx++;
            final row = item as Map<String, dynamic>;
            final name = htmlEscape.convert(
              '${row['product_name'] ?? row['product']?['name'] ?? 'Product'}',
            );
            final qty = row['quantity'] ?? 0;
            final totalVal = _fmtMoneyNum(row['total_price'] ?? 0);
            subtotal += totalVal;
            return '<tr>'
                '<td style="text-align:center;color:#6b7280;">$rowIdx</td>'
                '<td>$name</td>'
                '<td style="text-align:center;">$qty</td>'
                '<td style="text-align:right;">${_fmtMoney(row['unit_price'] ?? 0)} DH</td>'
                '<td style="text-align:right;">${_fmtMoney(row['total_price'] ?? 0)} DH</td>'
                '</tr>';
          }).join();

    if (subtotal == 0) {
      subtotal = _fmtMoneyNum(invoice['amount_due'] ?? invoice['amount'] ?? 0);
    }

    return '''
<section class="invoice">
  <div class="inv-header">
    <div class="inv-client">
      <div class="inv-label">BILL TO</div>
      <div class="inv-name">$retailerName</div>
      <div class="inv-detail">$retailerAddress</div>
      <div class="inv-detail">$retailerPhone</div>
    </div>
    <div class="inv-logo">
      <img class="inv-logo-image" src="$logoUrl" alt="$companyName logo">
      <div class="inv-brand-en">$companyName</div>
    </div>
    <div class="inv-company">
      <div class="inv-label">FROM</div>
      <div class="inv-name">$companyName</div>
      <div class="inv-detail">$companyAddress</div>
      <div class="inv-detail">$companyContact</div>
    </div>
  </div>
  <div class="inv-meta">
    <div class="inv-meta-item"><span class="inv-meta-label">Invoice</span><span>$invoiceNumber</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Order</span><span>$orderNumber</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Date</span><span>$createdDate</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Due</span><span>$dueDate</span></div>
    <div class="inv-meta-item"><span class="inv-meta-label">Status</span><span class="inv-status-badge">$status</span></div>
  </div>
  <table class="inv-table">
    <thead>
      <tr>
        <th style="width:40px;text-align:center;">#</th>
        <th>Product</th>
        <th style="width:60px;text-align:center;">Qty</th>
        <th style="width:100px;text-align:right;">Unit Price</th>
        <th style="width:100px;text-align:right;">Total</th>
      </tr>
    </thead>
    <tbody>$itemRows</tbody>
  </table>
  <div class="inv-totals">
    <div class="inv-total-row"><span>Subtotal</span><span>${_fmtMoney(subtotal)} DH</span></div>
    <div class="inv-total-row inv-grand-total"><span>TOTAL</span><span>$amountDue DH</span></div>
  </div>
</section>
''';
  }

  String _fmtMoney(dynamic value) {
    final v = _fmtMoneyNum(value);
    return v.toStringAsFixed(2);
  }

  double _fmtMoneyNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _zoneGeoJson() {
    final ring = _zonePoints
        .map((point) => [point.longitude, point.latitude])
        .toList();
    ring.add([_zonePoints.first.longitude, _zonePoints.first.latitude]);

    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }

  LatLng get _mapCenter {
    for (final order in _orders) {
      if (_isValidLatLng(order.deliveryLatitude, order.deliveryLongitude)) {
        return LatLng(order.deliveryLatitude!, order.deliveryLongitude!);
      }
    }
    return const LatLng(48.8566, 2.3522);
  }

  List<User> get _retailersMissingLocation {
    return _retailers
        .where((user) => user.latitude == null || user.longitude == null)
        .toList();
  }

  List<Marker> get _orderMarkers {
    final selectedIds = _previewOrders.map((order) => order.id).toSet();
    return _orders
        .where((order) {
          return _isValidLatLng(
            order.deliveryLatitude,
            order.deliveryLongitude,
          );
        })
        .map((order) {
          final isSelected = selectedIds.contains(order.id);
          return Marker(
            width: 46,
            height: 46,
            point: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
            alignment: Alignment.topCenter,
            child: Tooltip(
              message:
                  '${order.retailerName} - ${order.orderNumber ?? order.id}',
              child: GestureDetector(
                onTap: () => _showOrderDetails(order),
                child: Icon(
                  Icons.location_on_rounded,
                  size: isSelected ? 44 : 38,
                  color: isSelected ? AppColors.accent : AppColors.primary,
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 6),
                    Shadow(color: Colors.black26, blurRadius: 8),
                  ],
                ),
              ),
            ),
          );
        })
        .toList();
  }

  List<Marker> get _zoneMarkers {
    return _zonePoints.asMap().entries.map((entry) {
      return Marker(
        width: 28,
        height: 28,
        point: entry.value,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Text(
            '${entry.key + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _addZonePoint(LatLng point) {
    if (!_isDrawMode) return;
    setState(() {
      _zonePoints = [..._zonePoints, point];
      _previewOrders = [];
      _previewTotal = 0;
      _error = null;
    });
  }

  void _clearZone() {
    setState(() {
      _zonePoints = [];
      _previewOrders = [];
      _previewTotal = 0;
      _error = null;
    });
  }

  void _undoPoint() {
    if (_zonePoints.isEmpty) return;
    setState(() {
      _zonePoints = _zonePoints.sublist(0, _zonePoints.length - 1);
      _previewOrders = [];
      _previewTotal = 0;
    });
  }

  void _showOrderDetails(Order order) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => OrderDetailView(order: order)));
  }

  Future<void> _showRetailerLocationDialog(User retailer) async {
    final formKey = GlobalKey<FormState>();
    final addressController = TextEditingController(text: retailer.address);
    final latitudeController = TextEditingController(
      text: retailer.latitude?.toStringAsFixed(7) ?? '',
    );
    final longitudeController = TextEditingController(
      text: retailer.longitude?.toStringAsFixed(7) ?? '',
    );
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set Location for ${retailer.username}'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: LocationPickerFields(
                      addressController: addressController,
                      latitudeController: latitudeController,
                      longitudeController: longitudeController,
                      addressLabel: 'Retailer Address',
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (latitudeController.text.trim().isEmpty ||
                              longitudeController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select a map location before saving.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);

                          try {
                            await _apiService.client.put(
                              '/users/${retailer.id}',
                              data: {
                                'address': addressController.text.trim().isEmpty
                                    ? null
                                    : addressController.text.trim(),
                                'latitude': double.parse(
                                  latitudeController.text.trim(),
                                ),
                                'longitude': double.parse(
                                  longitudeController.text.trim(),
                                ),
                              },
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to save retailer location.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Location'),
                ),
              ],
            );
          },
        );
      },
    );

    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    if (saved == true) {
      _showMessage('Retailer location saved.');
      await _loadDispatchData();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  bool _isValidLatLng(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final map = _buildMap();
            final panel = _buildControlPanel();

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: map),
                  SizedBox(width: 360, child: panel),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: map),
                SizedBox(height: 300, child: panel),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.maxWidth.isFinite ||
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth <= 40 ||
                constraints.maxHeight <= 40) {
              return Container(
                color: const Color(0xFFE2E8F0),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.tr('map_unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 12,
                minZoom: 3,
                maxZoom: 18,
                onTap: (_, point) => _addZonePoint(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrlTemplate,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                ),
                if (_zonePoints.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _zonePoints,
                        color: AppColors.primary.withOpacity(0.18),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(markers: [..._orderMarkers, ..._zoneMarkers]),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution(MapConfig.attribution)],
                ),
              ],
            );
          },
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MapChip(
                icon: Icons.inventory_2_rounded,
                label: '${_orders.length} undispatched',
              ),
              if (_retailersMissingLocation.isNotEmpty)
                _MapChip(
                  icon: Icons.wrong_location_rounded,
                  label: '${_retailersMissingLocation.length} missing location',
                  color: AppColors.error,
                ),
              _MapChip(
                icon: _isDrawMode
                    ? Icons.edit_location_alt
                    : Icons.pan_tool_alt_rounded,
                label: _isDrawMode ? 'Tap map to draw' : 'Pan mode',
              ),
              if (_previewOrders.isNotEmpty)
                _MapChip(
                  icon: Icons.check_circle_rounded,
                  label: '${_previewOrders.length} selected',
                  color: AppColors.secondary,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissingRetailersSection() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _orders.isEmpty,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(
          Icons.wrong_location_rounded,
          color: AppColors.accent,
        ),
        title: const Text(
          'Retailers Missing Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_retailersMissingLocation.length} retailers need a map pin before their new orders can be dispatched by zone.',
          style: const TextStyle(fontSize: 12),
        ),
        children: _retailersMissingLocation.take(6).map((retailer) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_rounded),
            title: Text(retailer.username, overflow: TextOverflow.ellipsis),
            subtitle: Text(retailer.email, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Set location',
              onPressed: () => _showRetailerLocationDialog(retailer),
              icon: const Icon(Icons.add_location_alt_rounded),
            ),
            onTap: () => _showRetailerLocationDialog(retailer),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Map Dispatch', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Draw a zone around retailer locations, preview the matched orders, then assign them to a distributor.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (_retailersMissingLocation.isNotEmpty) ...[
            _buildMissingRetailersSection(),
            const SizedBox(height: 18),
          ],
          SwitchListTile(
            value: _isDrawMode,
            onChanged: (value) => setState(() => _isDrawMode = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Draw zone'),
            subtitle: Text('${_zonePoints.length} points'),
            secondary: const Icon(
              Icons.polyline_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _zonePoints.isEmpty ? null : _undoPoint,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _zonePoints.isEmpty ? null : _clearZone,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<User>(
            value: _selectedDistributor,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Distributor',
              prefixIcon: Icon(Icons.local_shipping_rounded),
            ),
            items: _distributors.map((user) {
              return DropdownMenuItem<User>(
                value: user,
                child: Text(user.username, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDistributor = value),
          ),
          const SizedBox(height: 18),
          _SummaryTile(
            icon: Icons.place_rounded,
            label: 'Orders in drawn zone',
            value: '${_previewOrders.length}',
          ),
          _SummaryTile(
            icon: Icons.payments_rounded,
            label: 'Zone value',
            value: '${_previewTotal.toStringAsFixed(2)} DH',
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _isPreviewing ? null : _previewZone,
            icon: _isPreviewing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.visibility_rounded),
            label: const Text('Preview Zone'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isDispatching || _previewOrders.isEmpty
                ? null
                : _dispatchZone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            icon: _isDispatching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Dispatch Selected Orders'),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            _previewOrders.isEmpty ? 'Undispatched Orders' : 'Previewed Orders',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...(_previewOrders.isEmpty ? _orders : _previewOrders).take(8).map((
            order,
          ) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
              ),
              title: Text(order.retailerName, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                order.orderNumber ?? order.deliveryAddress ?? order.id,
              ),
              trailing: Text('${order.totalAmount.toStringAsFixed(0)} DH'),
              onTap: () => _showOrderDetails(order),
            );
          }),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No undispatched orders with retailer coordinates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MapChip({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
