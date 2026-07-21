import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/map_config.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery.dart';

class DeliveryDetailView extends StatefulWidget {
  final DeliveryTask task;
  const DeliveryDetailView({super.key, required this.task});

  @override
  State<DeliveryDetailView> createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  // Signature Drawing State
  List<Offset?> _sigPoints = [];

  final ImagePicker _imagePicker = ImagePicker();
  bool _isCapturingPhoto = false;
  String? _capturedPhotoPath;
  Uint8List? _capturedPhotoBytes;
  LatLng? _currentLocation;
  bool _isLocating = false;
  String? _locationError;

  // Payment Collection State
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default cash collection to the remaining unpaid balance of the order
    _amountController.text = widget.task.order.remainingBalance.toStringAsFixed(
      2,
    );
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(context.tr('location_services_disabled'));
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(context.tr('location_permission_settings'));
      }
      if (permission == LocationPermission.denied) {
        throw Exception(context.tr('location_permission_denied'));
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.toString().replaceAll('Exception: ', '');
        _isLocating = false;
      });
    }
  }

  Future<void> _openRoadNavigation(DeliveryTask task) async {
    if (!_isValidLatLng(task.latitude, task.longitude)) return;

    final query = <String, String>{
      'api': '1',
      'destination': '${task.latitude},${task.longitude}',
      'travelmode': 'driving',
    };
    if (_currentLocation != null) {
      query['origin'] =
          '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    }

    try {
      final opened = await launchUrl(
        Uri.https('www.google.com', '/maps/dir/', query),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('navigation_open_failed')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _clearSignature() {
    setState(() {
      _sigPoints.clear();
    });
  }

  Future<Uint8List?> _renderSignaturePng() async {
    final visiblePoints = _sigPoints.whereType<Offset>().toList();
    if (visiblePoints.isEmpty) return null;

    double canvasWidth = 300;
    for (final point in visiblePoints) {
      if (point.dx + 16 > canvasWidth) canvasWidth = point.dx + 16;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, 150),
      Paint()..color = Colors.white,
    );
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var index = 0; index < _sigPoints.length - 1; index++) {
      final start = _sigPoints[index];
      final end = _sigPoints[index + 1];
      if (start != null && end != null) canvas.drawLine(start, end, paint);
    }

    final image = await recorder.endRecording().toImage(
      (canvasWidth * 2).ceil(),
      300,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _capturePhotoProof() async {
    setState(() {
      _isCapturingPhoto = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (!mounted) return;
      if (image == null) {
        setState(() => _isCapturingPhoto = false);
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _isCapturingPhoto = false;
        _capturedPhotoPath = image.path;
        _capturedPhotoBytes = bytes;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('photo_attached')),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCapturingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('camera_open_error')}: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitDelivery(BuildContext context, DeliveryTask task) async {
    if (task.status == DeliveryStatus.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('start_transit_first')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_sigPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('collect_signature_first')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_capturedPhotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('capture_photo_first')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final canCollectCash = _canCollectCash(context);
    final amountCollected = canCollectCash
        ? double.tryParse(_amountController.text) ?? 0.0
        : 0.0;
    if (amountCollected < 0.0 ||
        amountCollected > task.order.remainingBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .tr('invalid_payment_amount')
                .replaceFirst(
                  '{amount}',
                  task.order.remainingBalance.toStringAsFixed(2),
                ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final signatureBytes = await _renderSignaturePng();
    if (!context.mounted || signatureBytes == null) return;
    await provider.completeDelivery(
      task.id,
      signatureBytes: signatureBytes,
      photoBytes: _capturedPhotoBytes!,
      collectedAmount: amountCollected,
    );

    if (!context.mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('delivery_completed_success')),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = Provider.of<DeliveryProvider>(context);
    final task = delivery.tasks.firstWhere(
      (candidate) => candidate.id == widget.task.id,
      orElse: () => widget.task,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('${context.tr('delivery_label')} ${task.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Retailer Card
            _buildRetailerCard(task),
            const SizedBox(height: 16),

            _buildOrderedItemsCard(task),
            const SizedBox(height: 16),

            // Delivery Map
            _buildMapCard(task),
            const SizedBox(height: 16),

            // Photo Capture Section
            _buildPhotoCaptureSection(),
            const SizedBox(height: 16),

            // Signature Capture Section
            _buildSignatureSection(),
            const SizedBox(height: 16),

            // Payment Collection Section
            _buildPaymentCollectionSection(context, task),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(context, task),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRetailerCard(DeliveryTask task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.order.retailerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        context.tr('retailer_destination'),
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${context.tr('delivery_address')}:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.order.deliveryAddress ?? context.tr('no_delivery_address'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${context.tr('total_amount')}: ${task.order.totalAmount.toStringAsFixed(2)} DH',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderedItemsCard(DeliveryTask task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('ordered_items'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${task.order.items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task.order.items.isEmpty)
              Text(context.tr('no_order_items'))
            else
              ...task.order.items.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.quantity} x ${item.product.price.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
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

  Widget _buildMapCard(DeliveryTask task) {
    final hasCoordinates = _isValidLatLng(task.latitude, task.longitude);
    final destination = hasCoordinates
        ? LatLng(task.latitude, task.longitude)
        : const LatLng(48.8566, 2.3522);
    final routePoints = _currentLocation == null
        ? <LatLng>[]
        : [_currentLocation!, destination];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: hasCoordinates
                ? LayoutBuilder(
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
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return FlutterMap(
                        key: ValueKey(
                          _currentLocation == null
                              ? 'destination-${task.latitude}-${task.longitude}'
                              : 'route-${_currentLocation!.latitude}-${_currentLocation!.longitude}-${task.latitude}-${task.longitude}',
                        ),
                        options: MapOptions(
                          initialCenter: destination,
                          initialZoom: 15,
                          initialCameraFit: routePoints.isEmpty
                              ? null
                              : CameraFit.coordinates(
                                  coordinates: routePoints,
                                  padding: const EdgeInsets.all(44),
                                  maxZoom: 15,
                                ),
                          minZoom: 3,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapConfig.tileUrlTemplate,
                            userAgentPackageName:
                                MapConfig.userAgentPackageName,
                          ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  strokeWidth: 5,
                                  color: AppColors.primary,
                                  pattern: const StrokePattern.dotted(),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_currentLocation != null)
                                Marker(
                                  width: 42,
                                  height: 42,
                                  point: _currentLocation!,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                ),
                              Marker(
                                width: 48,
                                height: 48,
                                point: destination,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.error,
                                  size: 46,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 6),
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(MapConfig.attribution),
                            ],
                          ),
                        ],
                      );
                    },
                  )
                : Container(
                    color: const Color(0xFFE2E8F0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wrong_location_rounded,
                            color: AppColors.textLight,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('no_delivery_coordinates'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_isLocating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('locating_driver'),
                textAlign: TextAlign.center,
              ),
            ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _locationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (_locationError != null)
            TextButton.icon(
              onPressed: _isLocating ? null : _loadCurrentLocation,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('retry_location')),
            ),
          if (hasCoordinates)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: FilledButton.icon(
                onPressed: () => _openRoadNavigation(task),
                icon: const Icon(Icons.navigation_rounded),
                label: Text(context.tr('open_road_navigation')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasCoordinates
                          ? 'GPS: ${task.latitude.toStringAsFixed(4)}, ${task.longitude.toStringAsFixed(4)}'
                          : context.tr('gps_unavailable'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      hasCoordinates
                          ? context.tr('delivery_pin_saved')
                          : context.tr('location_needed'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasCoordinates
                            ? AppColors.secondary
                            : AppColors.error,
                      ),
                    ),
                    if (routePoints.isNotEmpty)
                      Text(
                        context.tr('direct_route_preview'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidLatLng(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude != 0.0 &&
        longitude != 0.0 &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  Widget _buildPhotoCaptureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  context.tr('photo_proof_label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isCapturingPhoto)
              Container(
                height: 150,
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('opening_camera'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_capturedPhotoPath != null)
              _buildCapturedPhotoPreview()
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _capturePhotoProof,
                icon: const Icon(Icons.camera_alt),
                label: Text(context.tr('attach_delivery_photo')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedPhotoPreview() {
    final bytes = _capturedPhotoBytes;
    final image = bytes == null
        ? Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.image_rounded)),
          )
        : Image.memory(
            bytes,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          );

    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.6),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _capturePhotoProof,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.draw_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('customer_signature'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _clearSignature,
                  child: Text(
                    context.tr('clear'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Custom Drawing Canvas
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _sigPoints.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _sigPoints.add(null);
                  });
                },
                child: CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: _SignaturePainter(points: _sigPoints),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCollectCash(BuildContext context) {
    return Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.canCollectCash ??
        false;
  }

  Widget _buildPaymentCollectionSection(
    BuildContext context,
    DeliveryTask task,
  ) {
    final canCollectCash = _canCollectCash(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('cash_payment_collection'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!canCollectCash) ...[
              Text(
                context.tr('cash_collection_disabled_msg'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('cash_collection_admin_msg'),
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ] else ...[
              Text(
                '${context.tr('remaining_balance')}: ${task.order.remainingBalance.toStringAsFixed(2)} DH',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '${context.tr('amount_collected')} (DH)',
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DeliveryTask task) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    if (task.status == DeliveryStatus.pending) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onPressed: () {
          provider.startDelivery(task.id).then((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  provider.error ?? context.tr('transit_started_msg'),
                ),
                backgroundColor: provider.error == null
                    ? AppColors.primary
                    : AppColors.error,
              ),
            );
          });
        },
        child: Text(context.tr('start_delivery_action')),
      );
    }

    if (task.status == DeliveryStatus.inTransit) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: () {
                provider.failDelivery(task.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('delivery_failed_msg')),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              child: Text(
                context.tr('mark_failed_action'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: () => _submitDelivery(context, task),
              child: Text(context.tr('submit_delivery_action')),
            ),
          ),
        ],
      );
    }

    return Card(
      color: Colors.green.withOpacity(0.1),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              context.tr('delivery_completed_success_banner'),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Painter for Signature ---

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        // Need to clamp drawing area so signature doesn't bleed out of the card
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
