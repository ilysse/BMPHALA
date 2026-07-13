import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../shared/app_back_guard.dart';
import 'catalog_view.dart';
import 'cart_view.dart';
import 'orders_view.dart';
import 'payments_view.dart';

class RetailerMainView extends StatefulWidget {
  const RetailerMainView({super.key});

  @override
  State<RetailerMainView> createState() => _RetailerMainViewState();
}

class _RetailerMainViewState extends State<RetailerMainView> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const CatalogView(),
    const CartView(),
    const OrdersView(),
    const PaymentsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return AppBackGuard(
      isAtRoot: _currentIndex == 0,
      onBackToRoot: () => setState(() => _currentIndex = 0),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                auth.currentUser?.username ?? context.tr('retailer_portal'),
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
        body: IndexedStack(index: _currentIndex, children: _views),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.grid_view_rounded),
              selectedIcon: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primary,
              ),
              label: context.tr('catalog'),
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${cart.totalQuantity}'),
                isLabelVisible: cart.totalQuantity > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                label: Text('${cart.totalQuantity}'),
                isLabelVisible: cart.totalQuantity > 0,
                child: const Icon(
                  Icons.shopping_cart,
                  color: AppColors.primary,
                ),
              ),
              label: context.tr('cart'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined),
              selectedIcon: const Icon(
                Icons.local_shipping,
                color: AppColors.primary,
              ),
              label: context.tr('orders'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.payment_rounded),
              selectedIcon: const Icon(
                Icons.payment_rounded,
                color: AppColors.primary,
              ),
              label: context.tr('payments'),
            ),
          ],
        ),
      ),
    );
  }
}
