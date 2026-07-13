import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_service.dart';

class AdminProductDetailView extends StatefulWidget {
  final Map<String, dynamic> productData;

  const AdminProductDetailView({super.key, required this.productData});

  @override
  State<AdminProductDetailView> createState() => _AdminProductDetailViewState();
}

class _AdminProductDetailViewState extends State<AdminProductDetailView> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _packSizeController;
  late TextEditingController _packUnitController;
  late TextEditingController _descriptionController;
  List<dynamic> _categories = [];
  List<dynamic> _brands = [];
  String? _categoryId;
  String? _brandId;
  String? _imageUrl;
  Uint8List? _localImageBytes;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final product = widget.productData;
    _nameController = TextEditingController(text: product['name'] ?? '');
    _skuController = TextEditingController(text: product['sku'] ?? '');
    _priceController = TextEditingController(
      text: (product['price'] ?? '').toString(),
    );
    _costPriceController = TextEditingController(
      text: (product['cost_price'] ?? '').toString(),
    );
    _packSizeController = TextEditingController(
      text: (product['pack_size'] ?? 1).toString(),
    );
    _packUnitController = TextEditingController(
      text: product['pack_unit'] ?? 'pcs',
    );
    _descriptionController = TextEditingController(
      text: product['description'] ?? '',
    );
    _categoryId = product['category_id'] as String?;
    _brandId = product['brand_id'] as String?;
    _imageUrl = product['image_url'] as String?;
    _isActive = product['is_active'] == true || product['is_active'] == 1;
    _fetchLookups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _packSizeController.dispose();
    _packUnitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchLookups() async {
    try {
      if (_apiService.mockMode) return;
      final responses = await Future.wait([
        _apiService.client.get(
          '/categories',
          queryParameters: {'per_page': 100},
        ),
        _apiService.client.get('/brands', queryParameters: {'per_page': 100}),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = responses[0].data['data'] ?? [];
        _brands = responses[1].data['data'] ?? [];
      });
    } catch (_) {
      // Product can still be edited without lookup refresh.
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();

    setState(() {
      _localImageBytes = bytes;
      _isUploading = true;
    });

    final uploadedPath = await _apiService.uploadImageBytes(
      bytes,
      pickedFile.name,
    );
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (uploadedPath != null) _imageUrl = uploadedPath;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploadedPath == null
              ? 'Image upload failed'
              : 'Image uploaded. Save to apply.',
        ),
        backgroundColor: uploadedPath == null
            ? AppColors.error
            : AppColors.secondary,
      ),
    );
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.put(
          '/products/${widget.productData['id']}',
          data: {
            'name': _nameController.text.trim(),
            'sku': _skuController.text.trim(),
            'price': double.parse(_priceController.text.trim()),
            'cost_price': _costPriceController.text.trim().isEmpty
                ? null
                : double.parse(_costPriceController.text.trim()),
            'pack_size': int.tryParse(_packSizeController.text.trim()) ?? 1,
            'pack_unit': _packUnitController.text.trim().isEmpty
                ? 'pcs'
                : _packUnitController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category_id': _categoryId,
            'brand_id': _brandId,
            'image_url': _imageUrl,
            'is_active': _isActive,
          },
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product saved from live backend.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating product: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${_nameController.text}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      if (!_apiService.mockMode) {
        await _apiService.client.delete(
          '/products/${widget.productData['id']}',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            tooltip: 'Delete product',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            onPressed: _isLoading ? null : _deleteProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    title: const Text('Active product'),
                    subtitle: const Text(
                      'Inactive products stay stored but can be hidden from live catalog filters.',
                    ),
                    secondary: const Icon(
                      Icons.toggle_on_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (DH)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: _requiredNumber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Cost Price (DH)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _packSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Pack Size',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _packUnitController,
                          decoration: const InputDecoration(
                            labelText: 'Pack Unit',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map<DropdownMenuItem<String>>((
                      category,
                    ) {
                      return DropdownMenuItem(
                        value: category['id'] as String,
                        child: Text(category['name'] ?? 'Category'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _brandId,
                    decoration: const InputDecoration(labelText: 'Brand'),
                    items: _brands.map<DropdownMenuItem<String>>((brand) {
                      return DropdownMenuItem(
                        value: brand['id'] as String,
                        child: Text(brand['name'] ?? 'Brand'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _brandId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _updateProduct,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Live Product'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    ImageProvider? provider;
    if (_localImageBytes != null) {
      provider = MemoryImage(_localImageBytes!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      provider = CachedNetworkImageProvider(_publicImageUrl(_imageUrl!));
    }

    return InkWell(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          image: provider == null
              ? null
              : DecorationImage(image: provider, fit: BoxFit.cover),
        ),
        child: _isUploading
            ? const Center(child: CircularProgressIndicator())
            : provider == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.textLight,
                      size: 42,
                    ),
                    SizedBox(height: 8),
                    Text('Upload product image'),
                  ],
                ),
              )
            : const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircleAvatar(child: Icon(Icons.edit_rounded)),
                ),
              ),
      ),
    );
  }

  String? _requiredNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Enter a number';
    return null;
  }

  String _publicImageUrl(String value) {
    return ApiService.publicImageUrl(value);
  }
}
