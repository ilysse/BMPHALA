import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/map_config.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';

class AdminRegistrationsView extends StatefulWidget {
  const AdminRegistrationsView({super.key});

  @override
  State<AdminRegistrationsView> createState() => _AdminRegistrationsViewState();
}

class _AdminRegistrationsViewState extends State<AdminRegistrationsView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _processing = {};

  List<_PendingRegistration> _registrations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PendingRegistration> get _filteredRegistrations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _registrations;

    return _registrations.where((registration) {
      return [
        registration.name,
        registration.email ?? '',
        registration.phone ?? '',
        registration.address ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _loadRegistrations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.client.get(
        '/users/registrations/pending',
        queryParameters: {'per_page': 100},
      );
      final payload = response.data as Map<String, dynamic>;
      final data = payload['data'] as List<dynamic>? ?? [];

      if (!mounted) return;
      setState(() {
        _registrations = data
            .map(
              (item) =>
                  _PendingRegistration.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(_PendingRegistration registration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.verified_user_rounded,
          color: AppColors.primary,
          size: 34,
        ),
        title: Text(context.tr('approve_registration')),
        content: Text(
          context
              .tr('approve_registration_confirm')
              .replaceAll('{name}', registration.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('approve_account')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _processing[registration.id] = 'approve');

    try {
      await _apiService.client.put('/users/${registration.id}/approve');
      if (!mounted) return;
      setState(
        () => _registrations.removeWhere((item) => item.id == registration.id),
      );
      _showMessage(context.tr('account_approved'), AppColors.primary);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${context.tr('approval_failed')}: ${_errorMessage(error)}',
        AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _processing.remove(registration.id));
    }
  }

  Future<void> _reject(_PendingRegistration registration) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.person_remove_rounded,
          color: AppColors.error,
          size: 34,
        ),
        title: Text(context.tr('reject_registration')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context
                  .tr('reject_registration_confirm')
                  .replaceAll('{name}', registration.name),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: context.tr('rejection_reason'),
                hintText: context.tr('rejection_reason_hint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: Text(context.tr('reject')),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null || !mounted) return;
    setState(() => _processing[registration.id] = 'reject');

    try {
      await _apiService.client.put(
        '/users/${registration.id}/reject',
        data: {'reason': reason.isEmpty ? null : reason},
      );
      if (!mounted) return;
      setState(
        () => _registrations.removeWhere((item) => item.id == registration.id),
      );
      _showMessage(context.tr('registration_rejected'), AppColors.secondary);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${context.tr('rejection_failed')}: ${_errorMessage(error)}',
        AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _processing.remove(registration.id));
    }
  }

  void _showLocation(_PendingRegistration registration) {
    if (!registration.hasLocation) {
      _showMessage(context.tr('location_not_provided'), AppColors.error);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => _RegistrationLocationDialog(registration: registration),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final registrations = _filteredRegistrations;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadRegistrations,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: _error!,
                  onRetry: _loadRegistrations,
                ),
              )
            else if (registrations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  hasSearch: _searchController.text.isNotEmpty,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 900 ? 2 : 1;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 390,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final registration = registrations[index];
                        return _RegistrationCard(
                          registration: registration,
                          action: _processing[registration.id],
                          onApprove: () => _approve(registration),
                          onReject: () => _reject(registration),
                          onViewLocation: () => _showLocation(registration),
                        );
                      }, childCount: registrations.length),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pending_registrations'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('registration_review_help'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${_registrations.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.tr('search_registrations'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? IconButton(
                      tooltip: context.tr('refresh'),
                      onPressed: _loadRegistrations,
                      icon: const Icon(Icons.refresh_rounded),
                    )
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final _PendingRegistration registration;
  final String? action;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewLocation;

  const _RegistrationCard({
    required this.registration,
    required this.action,
    required this.onApprove,
    required this.onReject,
    required this.onViewLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = action != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registration.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('submitted')} ${registration.formattedDate}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  context.tr('status_pending'),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailLine(
            icon: Icons.mail_outline_rounded,
            label: context.tr('email'),
            value: registration.email ?? '-',
          ),
          _DetailLine(
            icon: Icons.phone_outlined,
            label: context.tr('phone'),
            value: registration.phone ?? '-',
          ),
          if (registration.referredBy != null)
            _DetailLine(
              icon: Icons.hub_outlined,
              label: context.tr('referred_by'),
              value: registration.referredBy!,
            ),
          const SizedBox(height: 2),
          _LocationReviewPanel(
            registration: registration,
            onViewLocation: onViewLocation,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: action == 'reject'
                      ? const _ButtonLoader()
                      : const Icon(Icons.close_rounded, size: 18),
                  label: Text(context.tr('reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onApprove,
                  icon: action == 'approve'
                      ? const _ButtonLoader()
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(context.tr('approve_account')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationReviewPanel extends StatelessWidget {
  final _PendingRegistration registration;
  final VoidCallback onViewLocation;

  const _LocationReviewPanel({
    required this.registration,
    required this.onViewLocation,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = registration.hasLocation;
    final color = hasLocation ? AppColors.primary : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation
                ? Icons.location_on_rounded
                : Icons.wrong_location_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? registration.address ?? context.tr('seller_location')
                      : context.tr('location_not_provided'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasLocation ? AppColors.textPrimary : color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLocation
                      ? registration.formattedCoordinates
                      : context.tr('location_missing_review_warning'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasLocation)
            TextButton.icon(
              onPressed: onViewLocation,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: Text(context.tr('view_on_map')),
            ),
        ],
      ),
    );
  }
}

class _RegistrationLocationDialog extends StatelessWidget {
  final _PendingRegistration registration;

  const _RegistrationLocationDialog({required this.registration});

  Future<void> _openGoogleMaps(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': registration.formattedCoordinates,
    });

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show a localized error below if the browser cannot open the map URL.
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('map_open_failed')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(registration.latitude!, registration.longitude!);
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 760.0);
    final height = MediaQuery.sizeOf(context).height.clamp(500.0, 720.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.store_mall_directory_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('seller_location'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          registration.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapConfig.tileUrlTemplate,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 52,
                        height: 52,
                        point: point,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.error,
                          size: 50,
                          shadows: [
                            Shadow(color: Colors.white, blurRadius: 7),
                            Shadow(color: Colors.black26, blurRadius: 9),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          registration.address ?? context.tr('missing'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          registration.formattedCoordinates,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(context.tr('open_google_maps')),
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

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.task_alt_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? context.tr('no_items')
                  : context.tr('no_pending_registrations'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('no_pending_registrations_help'),
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('refresh')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRegistration {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? referredBy;
  final DateTime? createdAt;

  const _PendingRegistration({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.referredBy,
    this.createdAt,
  });

  factory _PendingRegistration.fromJson(Map<String, dynamic> json) {
    String? optional(dynamic value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    double? coordinate(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return _PendingRegistration(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: optional(json['email']),
      phone: optional(json['phone']),
      address: optional(json['address']),
      latitude: coordinate(json['latitude']),
      longitude: coordinate(json['longitude']),
      referredBy: optional(json['referred_by']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  bool get hasLocation {
    final lat = latitude;
    final lng = longitude;
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  String get formattedCoordinates {
    if (!hasLocation) return '-';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  String get formattedDate {
    final date = createdAt?.toLocal();
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
