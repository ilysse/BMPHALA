import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';

class AppBackGuard extends StatefulWidget {
  final Widget child;
  final bool isAtRoot;
  final VoidCallback? onBackToRoot;

  const AppBackGuard({
    super.key,
    required this.child,
    required this.isAtRoot,
    this.onBackToRoot,
  });

  @override
  State<AppBackGuard> createState() => _AppBackGuardState();
}

class _AppBackGuardState extends State<AppBackGuard> {
  DateTime? _lastRootBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (!widget.isAtRoot) {
          widget.onBackToRoot?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('back_to_home')),
              duration: const Duration(milliseconds: 1200),
            ),
          );
          return;
        }

        final now = DateTime.now();
        if (_lastRootBackPress != null &&
            now.difference(_lastRootBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }

        _lastRootBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('press_back_exit')),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primary,
          ),
        );
      },
      child: widget.child,
    );
  }
}
