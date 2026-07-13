import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/download_helper.dart';

import 'admin_product_detail_view.dart';

class AdminCatalogView extends StatefulWidget {
  const AdminCatalogView({super.key});

  @override
  State<AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends State<AdminCatalogView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _productSearchController =
      TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _brands = [];
  List<dynamic> _products = [];
  final Set<String> _updatingCatalogItemIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchData();
  }

  String get _activeBulkType {
    switch (_tabController.index) {
      case 0:
        return 'categories';
      case 1:
        return 'brands';
      default:
        return 'products';
    }
  }

  Future<void> _exportBulk() async {
    try {
      final type = _activeBulkType;
      final response = await _apiService.client.get(
        '/catalog/export',
        queryParameters: {'type': type},
      );
      final rows = (response.data['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final csv = _rowsToCsv(type, rows);
      await downloadTextFile(
        filename: 'halawat_$type.csv',
        content: csv,
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _showImportDialog() async {
    final type = _activeBulkType;
    final controller = TextEditingController(text: _templateCsv(type));
    final imported = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('bulk_import')} ${context.tr(type)}'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: controller,
            minLines: 12,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: 'CSV',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(context.tr('import')),
            onPressed: () async {
              try {
                final rows = _parseCsv(controller.text);
                if (!_apiService.mockMode) {
                  await _apiService.client.post(
                    '/catalog/import',
                    data: {'type': type, 'rows': rows},
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();
    if (imported == true) {
      await _fetchData();
    }
  }

  List<Map<String, dynamic>> _parseCsv(String input) {
    final lines = input
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return [];
    final headers = _splitCsvLine(lines.first);
    return lines.skip(1).map((line) {
      final values = _splitCsvLine(line);
      return {
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < values.length ? values[i] : '',
      };
    }).toList();
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        quoted = !quoted;
      } else if (char == ',' && !quoted) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  String _rowsToCsv(String type, List<Map<String, dynamic>> rows) {
    final headers = _headersFor(type);
    final buffer = StringBuffer(headers.join(','));
    for (final row in rows) {
      buffer.writeln();
      buffer.write(
        headers.map((header) => _csvCell(_valueFor(row, header))).join(','),
      );
    }
    return buffer.toString();
  }

  String _valueFor(Map<String, dynamic> row, String header) {
    if (header == 'category') return '${row['category']?['name'] ?? ''}';
    if (header == 'brand') return '${row['brand']?['name'] ?? ''}';
    return '${row[header] ?? ''}';
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return escaped.contains(',') || escaped.contains('\n')
        ? '"$escaped"'
        : escaped;
  }

  List<String> _headersFor(String type) {
    if (type == 'products') {
      return [
        'name',
        'sku',
        'price',
        'cost_price',
        'pack_size',
        'pack_unit',
        'category',
        'brand',
        'barcode',
        'description',
        'image_url',
        'is_active',
      ];
    }
    if (type == 'brands') return ['name', 'logo_url', 'is_active'];
    return ['name', 'image_url', 'sort_order', 'is_active'];
  }

  String _templateCsv(String type) {
    final headers = _headersFor(type);
    if (type == 'products') {
      return '${headers.join(',')}\nChocolate Box 250g,CHO-250,35,22,1,box,Sweets,Halawat,,Premium box,,true';
    }
    if (type == 'brands') {
      return '${headers.join(',')}\nHalawat,,true';
    }
    return '${headers.join(',')}\nSweets,,10,true';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _categories = [
          {
            'id': 'CAT1',
            'name': 'Beverages',
            'slug': 'beverages',
            'is_active': true,
          },
        ];
        _brands = [
          {'id': 'BR1', 'name': 'Evian', 'slug': 'evian', 'is_active': true},
        ];
        _products = [
          {
            'id': 'PR1',
            'name': 'Evian Water 500ml',
            'sku': 'EV-500',
            'price': 1.5,
            'category': _categories[0],
            'brand': _brands[0],
          },
        ];
      } else {
        final catRes = await _apiService.client.get(
          '/categories',
          queryParameters: {'per_page': 100},
        );
        final brandRes = await _apiService.client.get(
          '/brands',
          queryParameters: {'per_page': 100},
        );
        final prodRes = await _apiService.client.get(
          '/products',
          queryParameters: {'per_page': 100},
        );

        if (catRes.statusCode == 200) _categories = catRes.data['data'] ?? [];
        if (brandRes.statusCode == 200) _brands = brandRes.data['data'] ?? [];
        if (prodRes.statusCode == 200) _products = prodRes.data['data'] ?? [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _showAddCategoryDialog([Map<String, dynamic>? category]) async {
    await _showCatalogItemDialog(type: 'category', item: category);
  }

  Future<void> _showAddBrandDialog([Map<String, dynamic>? brand]) async {
    await _showCatalogItemDialog(type: 'brand', item: brand);
  }

  Future<void> _showCatalogItemDialog({
    required String type,
    Map<String, dynamic>? item,
  }) async {
    final isCategory = type == 'category';
    final isEditing = item != null;
    final endpoint = isCategory ? '/categories' : '/brands';
    final imageKey = isCategory ? 'image_url' : 'logo_url';
    final nameController = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    String? uploadedImageUrl = item?[imageKey]?.toString();
    bool isUploading = false;
    bool isSaving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            isEditing
                ? 'Edit ${isCategory ? context.tr('category') : context.tr('brand')}'
                : context.tr(isCategory ? 'add_category' : 'add_brand'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: context.tr(
                    isCategory ? 'category_name' : 'brand_name',
                  ),
                  errorText: dialogError,
                ),
              ),
              const SizedBox(height: 16),
              if (isUploading)
                const CircularProgressIndicator()
              else
                OutlinedButton.icon(
                  icon: Icon(
                    uploadedImageUrl == null
                        ? Icons.upload_file_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    uploadedImageUrl == null
                        ? context.tr(
                            isCategory ? 'upload_image' : 'upload_logo',
                          )
                        : context.tr(
                            isCategory ? 'image_uploaded' : 'logo_uploaded',
                          ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 75,
                            maxWidth: 1000,
                            maxHeight: 1000,
                          );
                          if (file == null) return;

                          setModalState(() {
                            isUploading = true;
                            dialogError = null;
                          });
                          try {
                            final path = await _apiService.uploadImageBytes(
                              await file.readAsBytes(),
                              file.name,
                            );
                            if (!dialogContext.mounted) return;
                            setModalState(() {
                              uploadedImageUrl = path ?? uploadedImageUrl;
                              if (path == null) {
                                dialogError = 'Image upload failed.';
                              }
                            });
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setModalState(
                              () => dialogError = 'Image upload failed: $error',
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setModalState(() => isUploading = false);
                            }
                          }
                        },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving || isUploading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
            FilledButton.icon(
              onPressed: isSaving || isUploading
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        setModalState(
                          () => dialogError = 'A name is required.',
                        );
                        return;
                      }

                      setModalState(() {
                        isSaving = true;
                        dialogError = null;
                      });
                      try {
                        if (!_apiService.mockMode) {
                          final data = {
                            'name': name,
                            imageKey: uploadedImageUrl,
                          };
                          if (isEditing) {
                            await _apiService.client.put(
                              '$endpoint/${item['id']}',
                              data: data,
                            );
                          } else {
                            await _apiService.client.post(endpoint, data: data);
                          }
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _fetchData();
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setModalState(() {
                          isSaving = false;
                          dialogError = 'Unable to save: $error';
                        });
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'Saving...' : context.tr('save')),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _setCatalogItemActive(
    Map<String, dynamic> item,
    String type,
    bool isActive,
  ) async {
    final itemId = item['id']?.toString();
    if (itemId == null || _updatingCatalogItemIds.contains(itemId)) return;

    final endpoint = type == 'category' ? '/categories' : '/brands';
    final previousValue = item['is_active'];
    setState(() {
      _updatingCatalogItemIds.add(itemId);
      item['is_active'] = isActive;
    });

    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put(
          '$endpoint/${item['id']}',
          data: {'is_active': isActive},
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => item['is_active'] = previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update status: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingCatalogItemIds.remove(itemId));
      }
    }
  }

  Future<void> _deleteCatalogItem(
    Map<String, dynamic> item,
    String type,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item['name']}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final endpoint = type == 'category' ? '/categories' : '/brands';
    setState(() => _isLoading = true);
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.delete('$endpoint/${item['id']}');
      }
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final packSizeController = TextEditingController(text: '1');
    final packUnitController = TextEditingController(text: 'pcs');
    final descriptionController = TextEditingController();
    String? selectedCategoryId = _categories.isNotEmpty
        ? _categories.first['id']
        : null;
    String? selectedBrandId = _brands.isNotEmpty ? _brands.first['id'] : null;
    String? uploadedImageUrl;
    bool isUploading = false;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(context.tr('add_product')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('product_name'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price (DH)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price (DH)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: packSizeController,
                  decoration: const InputDecoration(labelText: 'Pack Size'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: packUnitController,
                  decoration: const InputDecoration(labelText: 'Pack Unit'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) => setModalState(() => isActive = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active product'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: context.tr('category'),
                  ),
                  items: _categories
                      .map<DropdownMenuItem<String>>(
                        (c) => DropdownMenuItem(
                          value: c['id'],
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedBrandId,
                  decoration: InputDecoration(labelText: context.tr('brand')),
                  items: _brands
                      .map<DropdownMenuItem<String>>(
                        (b) => DropdownMenuItem(
                          value: b['id'],
                          child: Text(b['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedBrandId = val),
                ),
                const SizedBox(height: 16),
                isUploading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          uploadedImageUrl == null
                              ? context.tr('upload_image')
                              : context.tr('image_uploaded'),
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 800,
                            maxHeight: 800,
                          );
                          if (file != null) {
                            setModalState(() => isUploading = true);
                            final bytes = await file.readAsBytes();
                            final path = await _apiService.uploadImageBytes(
                              bytes,
                              file.name,
                            );
                            setModalState(() {
                              isUploading = false;
                              if (path != null) uploadedImageUrl = path;
                            });
                          }
                        },
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  if (!_apiService.mockMode) {
                    await _apiService.client.post(
                      '/products',
                      data: {
                        'name': nameController.text,
                        'sku': skuController.text,
                        'price': double.tryParse(priceController.text) ?? 0,
                        'cost_price': costPriceController.text.trim().isEmpty
                            ? null
                            : double.tryParse(costPriceController.text),
                        'pack_size': int.tryParse(packSizeController.text) ?? 1,
                        'pack_unit': packUnitController.text.isEmpty
                            ? 'pcs'
                            : packUnitController.text,
                        'description': descriptionController.text.trim(),
                        'category_id': selectedCategoryId,
                        'brand_id': selectedBrandId,
                        'image_url': uploadedImageUrl,
                        'is_active': isActive,
                      },
                    );
                  }
                  await _fetchData();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  setState(() => _isLoading = false);
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ERP Catalog Master Data',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(context.tr('import')),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _exportBulk,
                icon: const Icon(Icons.download_rounded),
                label: Text(context.tr('export')),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              icon: const Icon(Icons.category),
              text: context.tr('categories'),
            ),
            Tab(
              icon: const Icon(Icons.branding_watermark),
              text: context.tr('brands'),
            ),
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: context.tr('products'),
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(
                      _categories,
                      'category',
                      () => _showAddCategoryDialog(),
                    ),
                    _buildList(_brands, 'brand', () => _showAddBrandDialog()),
                    _buildProductList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildList(List<dynamic> items, String type, VoidCallback onAdd) {
    return Scaffold(
      body: items.isEmpty
          ? Center(child: Text(context.tr('no_items')))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index] as Map<String, dynamic>;
                  final isActive =
                      item['is_active'] == 1 || item['is_active'] == true;
                  final itemId = item['id']?.toString() ?? '';
                  final isUpdating = _updatingCatalogItemIds.contains(itemId);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: ListTile(
                      onTap: () => type == 'category'
                          ? _showAddCategoryDialog(item)
                          : _showAddBrandDialog(item),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? AppColors.secondary.withOpacity(0.12)
                            : AppColors.error.withOpacity(0.12),
                        child: Icon(
                          type == 'category'
                              ? Icons.category_rounded
                              : Icons.branding_watermark_rounded,
                          color: isActive
                              ? AppColors.secondary
                              : AppColors.error,
                        ),
                      ),
                      title: Text(item['name']?.toString() ?? ''),
                      subtitle: Text(
                        isActive
                            ? context.tr('active')
                            : context.tr('inactive'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isUpdating)
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            Switch(
                              value: isActive,
                              onChanged: (value) =>
                                  _setCatalogItemActive(item, type, value),
                            ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: isUpdating
                                ? null
                                : () => type == 'category'
                                      ? _showAddCategoryDialog(item)
                                      : _showAddBrandDialog(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: context.tr('delete'),
                            color: AppColors.error,
                            onPressed: isUpdating
                                ? null
                                : () => _deleteCatalogItem(item, type),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: type == 'category' ? 'fab-categories' : 'fab-brands',
        onPressed: onAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductList() {
    final query = _productSearchController.text.trim().toLowerCase();
    final products = query.isEmpty
        ? _products
        : _products.where((product) {
            return '${product['name'] ?? ''} ${product['sku'] ?? ''} ${product['category']?['name'] ?? ''} ${product['brand']?['name'] ?? ''}'
                .toLowerCase()
                .contains(query);
          }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _productSearchController,
              decoration: const InputDecoration(
                labelText: 'Search live products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? Center(child: Text(context.tr('no_items')))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final isActive =
                            item['is_active'] == true || item['is_active'] == 1;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? AppColors.secondary.withOpacity(0.12)
                                  : AppColors.error.withOpacity(0.12),
                              child: Icon(
                                isActive
                                    ? Icons.inventory_2_rounded
                                    : Icons.block_rounded,
                                color: isActive
                                    ? AppColors.secondary
                                    : AppColors.error,
                              ),
                            ),
                            title: Text(item['name'] ?? ''),
                            subtitle: Text(
                              'SKU: ${item['sku'] ?? 'N/A'} | Price: ${item['price'] ?? 0} DH | ${item['brand']?['name'] ?? 'No brand'}',
                            ),
                            trailing: Text(item['category']?['name'] ?? ''),
                            onTap: () async {
                              final shouldRefresh = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminProductDetailView(productData: item),
                                ),
                              );
                              if (shouldRefresh == true) {
                                _fetchData();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-products',
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
