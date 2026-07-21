import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../shared/legal_links.dart';

class WelcomeOnboardingView extends StatefulWidget {
  final VoidCallback onNewUser;
  final VoidCallback onExistingUser;

  const WelcomeOnboardingView({
    super.key,
    required this.onNewUser,
    required this.onExistingUser,
  });

  @override
  State<WelcomeOnboardingView> createState() => _WelcomeOnboardingViewState();
}

class _WelcomeOnboardingViewState extends State<WelcomeOnboardingView> {
  int _step = 0;
  String? _selectedLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLanguage ??= context.read<LanguageProvider>().locale.languageCode;
  }

  Future<void> _selectLanguage(String languageCode) async {
    setState(() => _selectedLanguage = languageCode);
    await context.read<LanguageProvider>().setLanguage(languageCode);
  }

  void _continue() {
    if (_selectedLanguage == null) return;
    setState(() => _step = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AtmosphereBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 34 : 18,
                    vertical: isWide ? 30 : 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isWide ? 60 : 36),
                      maxWidth: 1180,
                    ),
                    child: Center(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isWide ? 34 : 26),
                          border: Border.all(color: const Color(0xFFDDE8E3)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F12372D),
                              blurRadius: 48,
                              offset: Offset(0, 22),
                            ),
                          ],
                        ),
                        child: isWide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(
                                      flex: 5,
                                      child: _WelcomeStoryPanel(),
                                    ),
                                    Expanded(
                                      flex: 7,
                                      child: _buildJourneyPanel(isWide: true),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  const _WelcomeStoryPanel(compact: true),
                                  _buildJourneyPanel(isWide: false),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyPanel({required bool isWide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 52 : 22,
        isWide ? 44 : 28,
        isWide ? 52 : 22,
        isWide ? 44 : 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (_step == 1)
                IconButton.filledTonal(
                  tooltip: context.tr('back'),
                  onPressed: () => setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const SizedBox(width: 40),
              const Spacer(),
              _StepIndicator(currentStep: _step),
            ],
          ),
          SizedBox(height: isWide ? 44 : 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _step == 0 ? _buildLanguageStep() : _buildAccountStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageStep() {
    return Column(
      key: const ValueKey('language-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Eyebrow(text: context.tr('welcome_start_here')),
        const SizedBox(height: 12),
        Text(
          context.tr('welcome_language_title'),
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 34, height: 1.08),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('welcome_language_subtitle'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 30),
        _LanguageChoice(
          title: 'العربية',
          subtitle: 'متابعة بالعربية',
          badge: 'ع',
          selected: _selectedLanguage == 'ar',
          onTap: () => _selectLanguage('ar'),
        ),
        const SizedBox(height: 12),
        _LanguageChoice(
          title: 'English',
          subtitle: 'Continue in English',
          badge: 'EN',
          selected: _selectedLanguage == 'en',
          onTap: () => _selectLanguage('en'),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _selectedLanguage == null ? null : _continue,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(context.tr('continue')),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Column(
      key: const ValueKey('account-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Eyebrow(text: context.tr('welcome_choose_path')),
        const SizedBox(height: 12),
        Text(
          context.tr('welcome_account_title'),
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 34, height: 1.08),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('welcome_account_subtitle'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 28),
        _JourneyChoice(
          icon: Icons.storefront_rounded,
          accent: AppColors.secondary,
          title: context.tr('welcome_new_seller'),
          subtitle: context.tr('welcome_new_seller_subtitle'),
          action: context.tr('welcome_register_shop'),
          onTap: widget.onNewUser,
        ),
        const SizedBox(height: 14),
        _JourneyChoice(
          icon: Icons.lock_open_rounded,
          accent: AppColors.primary,
          title: context.tr('welcome_existing_user'),
          subtitle: context.tr('welcome_existing_user_subtitle'),
          action: context.tr('welcome_sign_in'),
          onTap: widget.onExistingUser,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: AppColors.textLight,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                context.tr('welcome_approval_note'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const LegalLinks(),
      ],
    );
  }
}

class _WelcomeStoryPanel extends StatelessWidget {
  final bool compact;

  const _WelcomeStoryPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 290 : null,
      constraints: compact ? null : const BoxConstraints(minHeight: 660),
      padding: EdgeInsets.all(compact ? 24 : 38),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E493B), Color(0xFF173E35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -85 : -70,
            right: compact ? -45 : -90,
            child: const _GlowOrb(size: 230, color: Color(0x33F2C46D)),
          ),
          Positioned(
            bottom: compact ? -130 : -100,
            left: compact ? -80 : -120,
            child: const _GlowOrb(size: 300, color: Color(0x1FFFFFFF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/branding/app_logo.jpg',
                        width: compact ? 56 : 70,
                        height: compact ? 56 : 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('app_title'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 20 : 24,
                          ),
                        ),
                        Text(
                          context.tr('welcome_trade_network'),
                          style: const TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Text(
                    context.tr('welcome_built_for_morocco'),
                    style: const TextStyle(
                      color: Color(0xFFEFD49A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('welcome_story_title'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('welcome_story_subtitle'),
                  style: const TextStyle(
                    color: Color(0xCFFFFFFF),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 34),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _StoryPill(
                      icon: Icons.inventory_2_outlined,
                      text: context.tr('catalog'),
                    ),
                    _StoryPill(
                      icon: Icons.receipt_long_outlined,
                      text: context.tr('orders'),
                    ),
                    _StoryPill(
                      icon: Icons.local_shipping_outlined,
                      text: context.tr('dispatch'),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  context.tr('welcome_footer'),
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                const Spacer(),
                Text(
                  context.tr('welcome_story_title'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('welcome_story_subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xCFFFFFFF),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChoice({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F8F4) : const Color(0xFFFAFBFA),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFDDE5E1),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 10),
                  ],
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontSize: badge.length == 1 ? 22 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyChoice extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _JourneyChoice({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFBFA),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFDDE5E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      action,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (index) {
        final active = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: index == currentStep ? 30 : 9,
          height: 9,
          margin: const EdgeInsetsDirectional.only(start: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : const Color(0xFFD9E3DF),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.secondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _StoryPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StoryPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFEFD49A), size: 17),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF6), Color(0xFFF0F7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0D155E4B)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
