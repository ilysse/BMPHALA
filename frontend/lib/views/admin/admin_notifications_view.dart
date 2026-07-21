import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';
import 'admin_notification_templates_view.dart';

class AdminNotificationsView extends StatefulWidget {
  const AdminNotificationsView({super.key});

  @override
  State<AdminNotificationsView> createState() => _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = false;
  bool _showUnreadOnly = false;
  String _typeFilter = 'all';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) _fetchData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _notifications = [
          {
            'id': 'NOT1',
            'type': 'product_restocked',
            'title': 'Product restocked',
            'body': 'Seasonal Juice is back in stock',
            'read_at': null,
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
      } else {
        final res = await _apiService.client.get(
          '/notifications',
          queryParameters: {'per_page': 100},
        );
        if (res.statusCode == 200) _notifications = res.data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<dynamic> get _visibleNotifications {
    return _notifications.where((item) {
      final matchesUnread = !_showUnreadOnly || item['read_at'] == null;
      final matchesType = _typeFilter == 'all' || item['type'] == _typeFilter;
      return matchesUnread && matchesType;
    }).toList();
  }

  Future<void> _markRead(dynamic item) async {
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put('/notifications/${item['id']}/read');
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to mark notification read: $e')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put('/notifications/read-all');
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to mark all read: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNotifications;
    final unreadCount = _notifications
        .where((item) => item['read_at'] == null)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$unreadCount unread notifications',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Unread only',
                        icon: Icon(
                          _showUnreadOnly
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          color: AppColors.primary,
                        ),
                        onPressed: () =>
                            setState(() => _showUnreadOnly = !_showUnreadOnly),
                      ),
                      IconButton(
                        tooltip: 'Manage Templates',
                        icon: const Icon(
                          Icons.edit_notifications_rounded,
                          color: AppColors.accent,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminNotificationTemplatesView(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Mark all read',
                        icon: const Icon(
                          Icons.done_all_rounded,
                          color: AppColors.secondary,
                        ),
                        onPressed: unreadCount == 0 ? null : _markAllRead,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _typeChip('all', 'All'),
                        _typeChip('product_new', 'New Products'),
                        _typeChip('product_restocked', 'Restocked'),
                        _typeChip('promotion', 'Promotions'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                  ? const Center(child: Text('No notifications'))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          final unread = item['read_at'] == null;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                _iconForType('${item['type'] ?? 'general'}'),
                                color: unread
                                    ? AppColors.primary
                                    : AppColors.textLight,
                              ),
                              title: Text(
                                item['title'] ?? '',
                                style: TextStyle(
                                  fontWeight: unread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                item['body'] ?? item['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: unread
                                  ? IconButton(
                                      tooltip: 'Mark read',
                                      icon: const Icon(Icons.check_rounded),
                                      onPressed: () => _markRead(item),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _typeFilter == value,
        onSelected: (_) => setState(() => _typeFilter = value),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'product_new':
        return Icons.new_releases_rounded;
      case 'product_restocked':
        return Icons.inventory_2_rounded;
      case 'promotion':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }
}
