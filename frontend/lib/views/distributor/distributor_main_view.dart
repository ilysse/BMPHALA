import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../shared/app_back_guard.dart';
import 'delivery_list_view.dart';

class DistributorMainView extends StatelessWidget {
  const DistributorMainView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return AppBackGuard(
      isAtRoot: true,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                auth.currentUser?.username ?? context.tr('distributor_portal'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.tr('sign_out')),
                    content: Text(context.tr('sign_out_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.tr('cancel')),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          auth.logout();
                        },
                        child: Text(
                          context.tr('sign_out'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: const DeliveryListView(),
      ),
    );
  }
}
