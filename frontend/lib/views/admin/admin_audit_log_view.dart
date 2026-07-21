import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';

class AdminAuditLogView extends StatefulWidget {
  const AdminAuditLogView({super.key});

  @override
  State<AdminAuditLogView> createState() => _AdminAuditLogViewState();
}

class _AdminAuditLogViewState extends State<AdminAuditLogView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        _logs = [
          {
            'id': 'LOG1',
            'action': 'created',
            'model_type': 'Order',
            'user': {'name': 'Admin'},
            'created_at': '2026-07-01',
          },
        ];
      } else {
        final res = await _apiService.client.get(
          '/audit-logs',
          queryParameters: {'per_page': 100},
        );
        if (res.statusCode == 200) _logs = res.data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading audit logs: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _logs;
    return _logs.where((item) {
      return '${item['action'] ?? ''} ${item['model_type'] ?? ''} ${item['user']?['name'] ?? ''} ${item['created_at'] ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  void _showLogDetails(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${item['action'] ?? 'Action'} ${item['model_type'] ?? ''}',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Detail(label: 'User', value: item['user']?['name'] ?? 'System'),
              _Detail(
                label: 'Model',
                value: item['model_type']?.toString() ?? 'N/A',
              ),
              _Detail(
                label: 'Model ID',
                value: item['model_id']?.toString() ?? 'N/A',
              ),
              _Detail(
                label: 'Created',
                value: item['created_at']?.toString() ?? 'N/A',
              ),
              const SizedBox(height: 12),
              Text(
                item.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search audit logs',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                  ? const Center(child: Text('No audit logs'))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final item = logs[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.history_rounded,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                '${item['action'] ?? 'action'} ${item['model_type'] ?? ''}',
                              ),
                              subtitle: Text(
                                'By ${item['user']?['name'] ?? 'System'} at ${item['created_at'] ?? ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _showLogDetails(item),
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
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;

  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
