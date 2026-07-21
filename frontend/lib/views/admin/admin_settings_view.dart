import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_service.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _otpEnabled = true;
  bool _updatingOtp = false;
  String? _logoUrl;
  String? _logoPath;
  Uint8List? _logoPreview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        _api.client.get('/company'),
        _api.client.get('/features'),
      ]);
      final company = responses[0].data['data'] as Map<String, dynamic>;
      final flags = responses[1].data['data'] as List<dynamic>? ?? [];
      final otpFlag = flags.cast<Map<String, dynamic>?>().firstWhere(
        (flag) => flag?['key'] == 'otp_login',
        orElse: () => null,
      );

      _nameController.text = '${company['name'] ?? ''}';
      _emailController.text = '${company['email'] ?? ''}';
      _phoneController.text = '${company['phone'] ?? ''}';
      _taxIdController.text = '${company['tax_id'] ?? ''}';
      _addressController.text = '${company['address'] ?? ''}';

      if (!mounted) return;
      setState(() {
        _logoUrl = company['logo_url'] as String?;
        _logoPath = company['logo_url'] as String?;
        _otpEnabled = otpFlag?['is_enabled'] as bool? ?? true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '${context.tr('settings_load_failed')}: $error';
        _loading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _logoPreview = bytes;
      _saving = true;
    });

    final path = await _api.uploadImageBytes(bytes, file.name);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (path != null) _logoPath = path;
    });

    if (path == null) {
      _showMessage(context.tr('logo_upload_failed'), isError: true);
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final response = await _api.client.put(
        '/company',
        data: {
          'name': _nameController.text.trim(),
          'email': _emptyToNull(_emailController.text),
          'phone': _emptyToNull(_phoneController.text),
          'tax_id': _emptyToNull(_taxIdController.text),
          'address': _emptyToNull(_addressController.text),
          'logo_url': _logoPath,
        },
      );
      if (!mounted) return;
      final data = response.data['data'] as Map<String, dynamic>;
      setState(() {
        _logoUrl = data['logo_url'] as String?;
        _logoPath = data['logo_url'] as String?;
        _logoPreview = null;
      });
      _showMessage(context.tr('company_settings_saved'));
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${context.tr('company_settings_save_failed')}: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setOtpEnabled(bool enabled) async {
    setState(() => _updatingOtp = true);
    try {
      final response = await _api.client.put(
        '/features/otp_login',
        data: {'is_enabled': enabled},
      );
      if (!mounted) return;
      final data = response.data['data'] as Map<String, dynamic>;
      setState(() => _otpEnabled = data['is_enabled'] as bool? ?? enabled);
      _showMessage(
        _otpEnabled
            ? context.tr('otp_login_enabled_message')
            : context.tr('otp_login_disabled_message'),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('${context.tr('otp_update_failed')}: $error', isError: true);
    } finally {
      if (mounted) setState(() => _updatingOtp = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.tr('refresh')),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.business_rounded),
                  text: context.tr('company_profile'),
                ),
                Tab(
                  icon: const Icon(Icons.password_rounded),
                  text: context.tr('login_and_otp'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [_buildCompanyTab(), _buildOtpTab()]),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ClipOval(child: _buildLogo()),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickLogo,
                    icon: const Icon(Icons.upload_rounded),
                    label: Text(context.tr('upload_company_logo')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('invoice_logo_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.tr('company_name'),
              prefixIcon: const Icon(Icons.business_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('required')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr('email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('phone'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _taxIdController,
            decoration: InputDecoration(
              labelText: context.tr('tax_id'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.tr('address'),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveCompany,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    if (_logoPreview != null) {
      return Image.memory(
        _logoPreview!,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
      );
    }
    if (_logoUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: _logoUrl!,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Image.asset(
          'assets/branding/app_logo.jpg',
          width: 112,
          height: 112,
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      'assets/branding/app_logo.jpg',
      width: 112,
      height: 112,
      fit: BoxFit.cover,
    );
  }

  Widget _buildOtpTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: SwitchListTile.adaptive(
            value: _otpEnabled,
            onChanged: _updatingOtp ? null : _setOtpEnabled,
            secondary: Icon(
              _otpEnabled
                  ? Icons.verified_user_rounded
                  : Icons.no_accounts_rounded,
              color: _otpEnabled ? AppColors.secondary : AppColors.error,
            ),
            title: Text(context.tr('otp_login')),
            subtitle: Text(context.tr('otp_login_control_description')),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.primary.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('otp_existing_user_explanation'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
