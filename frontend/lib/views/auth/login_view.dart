import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import 'onboarding_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpPhoneController = TextEditingController();
  final _otpCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _otpRequested = false;
  String _otpChannel = 'sms';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().loadAuthConfig();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpPhoneController.dispose();
    _otpCodeController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('success')}: Welcome back, ${auth.currentUser?.username}!',
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
      // Main routing is handled in main.dart based on Auth state
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? context.tr('error')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _requestOtp(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.requestOtp(
      phone: _otpPhoneController.text,
      channel: _otpChannel,
    );

    if (!mounted) return;

    setState(() => _otpRequested = success);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('otp_sent_message')
              : auth.error ?? context.tr('unable_send_otp'),
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }

  Future<void> _verifyOtp(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(
      phone: _otpPhoneController.text,
      channel: _otpChannel,
      code: _otpCodeController.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${context.tr('success')}: ${auth.currentUser?.username ?? ''}'
              : auth.error ?? context.tr('otp_verification_failed'),
        ),
        backgroundColor: success ? AppColors.secondary : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF1F8F5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/branding/app_logo.jpg',
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('app_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('app_subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Glassmorphic Login Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCE9E4)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: _buildLoginCard(auth),
                    ),
                    const SizedBox(height: 24),

                    // Onboarding Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${context.tr('new_retailer')} ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            auth.clearError();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OnboardingView(),
                              ),
                            );
                            if (!mounted) return;
                            auth.clearError();
                          },
                          child: Text(
                            context.tr('register_here'),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Language Switcher floating at the top (Moved to end of Stack to receive taps)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Consumer<LanguageProvider>(
                builder: (context, lang, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE9E4)),
                    ),
                    child: DropdownButton<String>(
                      value: lang.locale.languageCode,
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.language,
                        color: AppColors.primary,
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      ],
                      onChanged: (val) {
                        if (val != null) lang.setLanguage(val);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(AuthProvider auth) {
    final title = Text(
      context.tr('login'),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 22,
      ),
    );

    if (!auth.otpLoginEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          if (!auth.authConfigLoaded) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.tr('otp_login_disabled_by_admin'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(height: 300, child: _buildPasswordLogin(auth)),
        ],
      );
    }

    return DefaultTabController(
      key: const ValueKey('otp-login-enabled'),
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 16),
          TabBar(
            tabs: [
              Tab(text: context.tr('password_login')),
              Tab(text: context.tr('phone_otp')),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [_buildPasswordLogin(auth), _buildOtpLogin(auth)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordLogin(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: AppColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr('email_or_phone'),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Enter your email or phone number'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(color: AppColors.textPrimary),
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: context.tr('password'),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.textSecondary,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) => val == null || val.length < 8
                ? 'Password must be 8+ chars'
                : null,
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 14),
            _buildErrorPanel(auth.error!),
          ],
          const SizedBox(height: 24),
          _buildAuthButton(
            auth: auth,
            label: context.tr('login'),
            onPressed: () => _submit(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpLogin(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otpPhoneController,
          style: const TextStyle(color: AppColors.textPrimary),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('phone_number'),
            prefixIcon: const Icon(
              Icons.phone_iphone_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'sms',
              icon: Icon(Icons.sms_rounded),
              label: Text('SMS'),
            ),
            ButtonSegment(
              value: 'whatsapp',
              icon: Icon(Icons.chat_rounded),
              label: Text('WhatsApp'),
            ),
          ],
          selected: {_otpChannel},
          onSelectionChanged: (value) {
            setState(() => _otpChannel = value.first);
          },
        ),
        const SizedBox(height: 12),
        if (_otpRequested)
          TextFormField(
            controller: _otpCodeController,
            style: const TextStyle(color: AppColors.textPrimary),
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: context.tr('six_digit_code'),
              counterText: '',
              prefixIcon: const Icon(
                Icons.pin_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          _buildErrorPanel(auth.error!),
        ],
        const SizedBox(height: 16),
        _buildAuthButton(
          auth: auth,
          label: _otpRequested
              ? context.tr('verify_otp')
              : context.tr('send_otp'),
          onPressed: () =>
              _otpRequested ? _verifyOtp(context) : _requestOtp(context),
        ),
      ],
    );
  }

  Widget _buildErrorPanel(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton({
    required AuthProvider auth,
    required String label,
    required VoidCallback onPressed,
  }) {
    if (auth.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shadowColor: AppColors.primary.withOpacity(0.25),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
