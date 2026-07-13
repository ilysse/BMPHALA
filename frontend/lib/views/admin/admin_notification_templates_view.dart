import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';

class AdminNotificationTemplatesView extends StatefulWidget {
  const AdminNotificationTemplatesView({super.key});

  @override
  State<AdminNotificationTemplatesView> createState() =>
      _AdminNotificationTemplatesViewState();
}

class _AdminNotificationTemplatesViewState
    extends State<AdminNotificationTemplatesView>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _fabAnimController;

  // ── Event type metadata ──────────────────────────────────────────────
  static const Map<String, _EventMeta> _eventMeta = {
    'product_new': _EventMeta(
      icon: Icons.new_releases_rounded,
      label: 'New Product',
      color: Color(0xFF059669),
      variables: ['{product_name}', '{product_price}', '{category_name}'],
    ),
    'product_restocked': _EventMeta(
      icon: Icons.inventory_2_rounded,
      label: 'Product Restocked',
      color: Color(0xFF2563EB),
      variables: ['{product_name}', '{quantity}', '{warehouse_name}'],
    ),
    'promotion_new': _EventMeta(
      icon: Icons.local_offer_rounded,
      label: 'New Promotion',
      color: Color(0xFFC58A2B),
      variables: ['{promotion_name}', '{discount_value}', '{expiry_date}'],
    ),
    'promotion_updated': _EventMeta(
      icon: Icons.campaign_rounded,
      label: 'Promotion Updated',
      color: Color(0xFF9333EA),
      variables: ['{promotion_name}', '{discount_value}', '{expiry_date}'],
    ),
    'order_placed': _EventMeta(
      icon: Icons.shopping_cart_checkout_rounded,
      label: 'Order Placed',
      color: Color(0xFF0891B2),
      variables: ['{order_id}', '{customer_name}', '{total_amount}'],
    ),
    'order_shipped': _EventMeta(
      icon: Icons.local_shipping_rounded,
      label: 'Order Shipped',
      color: Color(0xFF0D9488),
      variables: ['{order_id}', '{tracking_number}', '{delivery_date}'],
    ),
    'payment_received': _EventMeta(
      icon: Icons.payments_rounded,
      label: 'Payment Received',
      color: Color(0xFF16A34A),
      variables: ['{invoice_id}', '{amount}', '{customer_name}'],
    ),
  };

  static _EventMeta _metaFor(String eventType) {
    return _eventMeta[eventType] ??
        const _EventMeta(
          icon: Icons.notifications_active_rounded,
          label: 'Custom Event',
          color: AppColors.textSecondary,
          variables: [],
        );
  }

  static String _localizedEventLabel(BuildContext context, String eventType) {
    final key = 'event_$eventType';
    final trans = context.tr(key);
    if (trans == key) {
      return _metaFor(eventType).label;
    }
    return trans;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fetchTemplates();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  // ── Data fetching ────────────────────────────────────────────────────
  Future<void> _fetchTemplates() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _templates = [
          {
            'id': 'TPL-001',
            'event_type': 'product_new',
            'title_template': 'New arrival: {product_name}',
            'body_template':
                'Check out {product_name} now available in {category_name} at just {product_price}!',
            'is_active': true,
          },
          {
            'id': 'TPL-002',
            'event_type': 'product_restocked',
            'title_template': '{product_name} is back in stock!',
            'body_template':
                'Great news — {product_name} has been restocked with {quantity} units at {warehouse_name}.',
            'is_active': true,
          },
          {
            'id': 'TPL-003',
            'event_type': 'promotion_new',
            'title_template': 'New Promotion: {promotion_name}',
            'body_template':
                'Save {discount_value} with our latest promotion "{promotion_name}". Offer valid until {expiry_date}.',
            'is_active': true,
          },
          {
            'id': 'TPL-004',
            'event_type': 'promotion_updated',
            'title_template': 'Promotion updated: {promotion_name}',
            'body_template':
                'The promotion "{promotion_name}" has been updated. New discount: {discount_value}. Expires {expiry_date}.',
            'is_active': false,
          },
        ];
      } else {
        final res = await _apiService.client.get('/notification-templates');
        if (res.statusCode == 200 && res.data['success'] == true) {
          _templates =
              List<Map<String, dynamic>>.from(res.data['data'] ?? []);
        }
      }
      _fabAnimController.forward();
    } catch (e) {
      _errorMessage = 'Failed to load templates: $e';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ── Toggle active ────────────────────────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> template) async {
    final newValue = !(template['is_active'] as bool);
    final previousValue = template['is_active'];

    setState(() => template['is_active'] = newValue);

    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put(
          '/notification-templates/${template['id']}',
          data: {'is_active': newValue},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? context.tr('template_activated') : context.tr('template_deactivated'),
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: newValue ? AppColors.primary : AppColors.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => template['is_active'] = previousValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('failed_update_status')}: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Edit dialog ──────────────────────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> template) async {
    final meta = _metaFor(template['event_type'] as String);
    final titleCtrl =
        TextEditingController(text: template['title_template'] as String);
    final bodyCtrl =
        TextEditingController(text: template['body_template'] as String);
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [meta.color.withOpacity(0.08), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: meta.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(meta.icon, color: meta.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('edit_template'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _localizedEventLabel(context, template['event_type'] as String),
                            style: TextStyle(
                              fontSize: 13,
                              color: meta.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('title_template'),
                          hintText: 'e.g. New arrival: {product_name}',
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bodyCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('body_template'),
                          hintText: 'Notification body with variables…',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 14),
                      _buildVariableChips(meta.variables),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: Text(
                    context.tr('cancel'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty ||
                              bodyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('title_body_required'),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            if (!_apiService.mockMode) {
                              await _apiService.client.put(
                                '/notification-templates/${template['id']}',
                                data: {
                                  'title_template': titleCtrl.text.trim(),
                                  'body_template': bodyCtrl.text.trim(),
                                },
                              );
                            }
                            template['title_template'] =
                                titleCtrl.text.trim();
                            template['body_template'] =
                                bodyCtrl.text.trim();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${context.tr('save_failed')}: $e'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
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
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(isSaving ? context.tr('saving') : context.tr('save')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();

    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('template_updated')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Create dialog ────────────────────────────────────────────────────
  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedEventType;
    bool isSaving = false;

    // Filter out event types that already have templates
    final existingTypes =
        _templates.map((t) => t['event_type'] as String).toSet();
    final availableTypes = _eventMeta.keys
        .where((type) => !existingTypes.contains(type))
        .toList();

    if (availableTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('all_types_exist'),
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentMeta = selectedEventType != null
                ? _metaFor(selectedEventType!)
                : null;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_alert_rounded,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr('new_notification_template'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedEventType,
                        decoration: InputDecoration(
                          labelText: context.tr('type'),
                          prefixIcon: const Icon(Icons.event_rounded),
                        ),
                        items: availableTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(_metaFor(type).icon, size: 18, color: _metaFor(type).color),
                                const SizedBox(width: 10),
                                Text(_localizedEventLabel(context, type)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedEventType = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('title_template'),
                          hintText: 'e.g. New arrival: {product_name}',
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bodyCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('body_template'),
                          hintText: 'Notification body with variables…',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 14),
                      if (currentMeta != null)
                        _buildVariableChips(currentMeta.variables),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: Text(
                    context.tr('cancel'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedEventType == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('event_type_required'),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            return;
                          }
                          if (titleCtrl.text.trim().isEmpty ||
                              bodyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('title_body_required'),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            if (_apiService.mockMode) {
                              _templates.add({
                                'id':
                                    'TPL-${DateTime.now().millisecondsSinceEpoch}',
                                'event_type': selectedEventType,
                                'title_template': titleCtrl.text.trim(),
                                'body_template': bodyCtrl.text.trim(),
                                'is_active': true,
                              });
                            } else {
                              final res = await _apiService.client.post(
                                '/notification-templates',
                                data: {
                                  'event_type': selectedEventType,
                                  'title_template': titleCtrl.text.trim(),
                                  'body_template': bodyCtrl.text.trim(),
                                },
                              );
                              if (res.statusCode == 201 ||
                                  res.statusCode == 200) {
                                if (res.data['data'] != null) {
                                  _templates.add(
                                    Map<String, dynamic>.from(
                                      res.data['data'],
                                    ),
                                  );
                                }
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${context.tr('create_failed')}: $e'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
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
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(isSaving ? context.tr('creating') : context.tr('create')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();

    if (created == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('template_created')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Variable chips helper ────────────────────────────────────────────
  Widget _buildVariableChips(List<String> variables) {
    if (variables.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.data_object_rounded,
                size: 14, color: AppColors.textLight),
            const SizedBox(width: 6),
            Text(
              'Available variables — tap to copy',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: variables.map((v) {
            return ActionChip(
              avatar: Icon(Icons.code_rounded,
                  size: 14, color: AppColors.primary.withOpacity(0.7)),
              label: Text(
                v,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.primary.withOpacity(0.06),
              side: BorderSide(color: AppColors.primary.withOpacity(0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: () {
                // Copy variable to clipboard simulation — in real app, use Clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $v'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.tr('new_template')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final activeCount =
        _templates.where((t) => t['is_active'] == true).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('notification_templates'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_templates.length} ${context.tr('templates')} · $activeCount ${context.tr('active')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('refresh'),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchTemplates,
          ),
        ],
      ),
    );
  }

  // ── Body states ──────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('loading_templates'),
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('something_wrong'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _fetchTemplates,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.tr('retry')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  color: AppColors.primary.withOpacity(0.4),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('no_templates_yet'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('create_first_template'),
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('create_template')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTemplates,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          return _buildTemplateCard(_templates[index], index);
        },
      ),
    );
  }

  // ── Template card ────────────────────────────────────────────────────
  Widget _buildTemplateCard(Map<String, dynamic> template, int index) {
    final meta = _metaFor(template['event_type'] as String);
    final isActive = template['is_active'] as bool;
    final title = template['title_template'] as String;
    final body = template['body_template'] as String;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? meta.color.withOpacity(0.18)
                : Colors.grey.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? meta.color : Colors.grey).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showEditDialog(template),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + label + active toggle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(isActive ? 0.10 : 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          meta.icon,
                          color: isActive
                              ? meta.color
                              : AppColors.textLight,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _localizedEventLabel(context, template['event_type'] as String),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? meta.color.withOpacity(0.08)
                                    : Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                template['event_type'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: isActive
                                      ? meta.color
                                      : AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (_) => _toggleActive(template),
                            activeColor: meta.color,
                            activeTrackColor: meta.color.withOpacity(0.30),
                          ),
                          Text(
                            isActive ? context.tr('active') : context.tr('inactive'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? meta.color
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          meta.color.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title template
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.title_rounded,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Body preview
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          body,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Tap hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: AppColors.textLight.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('tap_to_edit'),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Event metadata helper class ──────────────────────────────────────────
class _EventMeta {
  final IconData icon;
  final String label;
  final Color color;
  final List<String> variables;

  const _EventMeta({
    required this.icon,
    required this.label,
    required this.color,
    required this.variables,
  });
}
