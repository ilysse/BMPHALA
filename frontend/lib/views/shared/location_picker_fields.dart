import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';

class LocationPickerFields extends StatelessWidget {
  final TextEditingController addressController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final String addressLabel;
  final bool required;

  const LocationPickerFields({
    super.key,
    required this.addressController,
    required this.latitudeController,
    required this.longitudeController,
    this.addressLabel = 'Address',
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: addressController,
          decoration: InputDecoration(
            labelText: addressLabel == 'Address'
                ? context.tr('address')
                : addressLabel,
            prefixIcon: const Icon(
              Icons.location_city,
              color: AppColors.primary,
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (required && text.isEmpty) return context.tr('required');
            if (text.length > 500) return context.tr('address_under_500');
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('latitude'),
                  prefixIcon: const Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                  ),
                ),
                validator: (value) => _validateLatitude(context, value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('longitude'),
                  prefixIcon: const Icon(
                    Icons.explore,
                    color: AppColors.primary,
                  ),
                ),
                validator: (value) => _validateLongitude(context, value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showMapPicker(context),
          icon: const Icon(Icons.map_rounded),
          label: Text(context.tr('verify_location_on_map')),
        ),
      ],
    );
  }

  String? _validateLatitude(BuildContext context, String? value) {
    final text = value?.trim() ?? '';
    final longitude = longitudeController.text.trim();
    if (text.isEmpty && longitude.isEmpty && !required) return null;
    if (text.isEmpty) return context.tr('required');
    final latitude = double.tryParse(text);
    if (!_isValidLatitude(latitude)) {
      return context.tr('invalid');
    }
    return null;
  }

  String? _validateLongitude(BuildContext context, String? value) {
    final text = value?.trim() ?? '';
    final latitude = latitudeController.text.trim();
    if (text.isEmpty && latitude.isEmpty && !required) return null;
    if (text.isEmpty) return context.tr('required');
    final longitude = double.tryParse(text);
    if (!_isValidLongitude(longitude)) {
      return context.tr('invalid');
    }
    return null;
  }

  LatLng _initialPoint() {
    final latitude = double.tryParse(latitudeController.text.trim());
    final longitude = double.tryParse(longitudeController.text.trim());
    if (_isValidLatitude(latitude) && _isValidLongitude(longitude)) {
      return LatLng(latitude!, longitude!);
    }

    return const LatLng(48.8566, 2.3522);
  }

  void _setControllers(LatLng point) {
    latitudeController.text = point.latitude.toStringAsFixed(7);
    longitudeController.text = point.longitude.toStringAsFixed(7);
  }

  bool _isValidLatitude(double? value) {
    return value != null && value.isFinite && value >= -90 && value <= 90;
  }

  bool _isValidLongitude(double? value) {
    return value != null && value.isFinite && value >= -180 && value <= 180;
  }

  Future<void> _showMapPicker(BuildContext context) async {
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (context) =>
          _LocationPickerDialog(initialPoint: _initialPoint()),
    );

    if (selected != null) {
      _setControllers(selected);
    }
  }
}

class _LocationPickerDialog extends StatefulWidget {
  final LatLng initialPoint;

  const _LocationPickerDialog({required this.initialPoint});

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final MapController _mapController = MapController();
  late LatLng _selectedPoint;
  bool _isLocating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw Exception(context.tr('turn_on_location_retry'));
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
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
      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _selectedPoint = point;
        _isLocating = false;
      });
      _mapController.move(point, 16);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
        _isLocating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width.clamp(320.0, 760.0);
    final dialogHeight = MediaQuery.of(context).size.height.clamp(520.0, 720.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('verify_shop_location'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_hasUsableMapSize(constraints)) {
                        return _MapUnavailable(
                          message: context.tr('map_unavailable'),
                        );
                      }

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedPoint,
                          initialZoom: 14,
                          minZoom: 3,
                          maxZoom: 18,
                          onTap: (_, point) => setState(() {
                            _selectedPoint = point;
                            _error = null;
                          }),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapConfig.tileUrlTemplate,
                            userAgentPackageName:
                                MapConfig.userAgentPackageName,
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 48,
                                height: 48,
                                point: _selectedPoint,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 46,
                                  color: AppColors.error,
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
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          context.tr('location_help'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_selectedPoint.latitude.toStringAsFixed(7)}, ${_selectedPoint.longitude.toStringAsFixed(7)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _useCurrentLocation,
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.gps_fixed_rounded),
                          label: Text(context.tr('use_current_location')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pop(_selectedPoint),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(context.tr('use_this_pin')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasUsableMapSize(BoxConstraints constraints) {
    return constraints.maxWidth.isFinite &&
        constraints.maxHeight.isFinite &&
        constraints.maxWidth > 40 &&
        constraints.maxHeight > 40;
  }
}

class _MapUnavailable extends StatelessWidget {
  final String message;

  const _MapUnavailable({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
