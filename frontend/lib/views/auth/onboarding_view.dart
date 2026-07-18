import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../shared/location_picker_fields.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onRegistrationSubmitted;

  const OnboardingView({super.key, this.onBack, this.onRegistrationSubmitted});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _shopNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.onboardRetailer(
      shopName: _shopNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      referralCode: _referralController.text.trim().isEmpty
          ? null
          : _referralController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      latitude: _latitudeController.text.trim().isEmpty
          ? null
          : double.parse(_latitudeController.text.trim()),
      longitude: _longitudeController.text.trim().isEmpty
          ? null
          : double.parse(_longitudeController.text.trim()),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('registration_submitted_approval')),
          backgroundColor: AppColors.secondary,
        ),
      );
      if (widget.onRegistrationSubmitted != null) {
        widget.onRegistrationSubmitted!();
      } else {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? context.tr('onboarding_failed')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('retailer_onboarding'),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: Container(
        height: double.infinity,
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome header
              Text(
                context.tr('join_bmp_network'),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('registration_intro'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

              // Form Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Shop Name Field
                        TextFormField(
                          controller: _shopNameController,
                          decoration: InputDecoration(
                            labelText: context.tr('shop_name'),
                            prefixIcon: const Icon(
                              Icons.storefront,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty
                              ? context.tr('enter_shop_name')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: context.tr('email_optional_with_phone'),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) {
                            final email = val?.trim() ?? '';
                            final phone = _phoneController.text.trim();
                            if (email.isEmpty && phone.isEmpty) {
                              return context.tr('enter_email_or_phone');
                            }
                            if (email.isNotEmpty && !email.contains('@')) {
                              return context.tr('enter_valid_email');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: context.tr('phone_optional_with_email'),
                            hintText: context.tr('phone_example'),
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (val) {
                            final phone = val?.trim() ?? '';
                            final email = _emailController.text.trim();
                            if (phone.isEmpty && email.isEmpty) {
                              return context.tr('enter_email_or_phone');
                            }
                            if (phone.isNotEmpty && phone.length < 8) {
                              return context.tr('enter_valid_phone');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: context.tr('password'),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (val) => val == null || val.length < 8
                              ? context.tr('password_min_8')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Referral Code (Optional)
                        TextFormField(
                          controller: _referralController,
                          decoration: InputDecoration(
                            labelText: context.tr('referral_code_optional'),
                            hintText: context.tr('referral_code_example'),
                            prefixIcon: const Icon(
                              Icons.card_membership,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('referral_help'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LocationPickerFields(
                          addressController: _addressController,
                          latitudeController: _latitudeController,
                          longitudeController: _longitudeController,
                          addressLabel: context.tr('shop_address'),
                          required: true,
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        auth.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                                onPressed: _submit,
                                child: Text(context.tr('submit_onboarding')),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
