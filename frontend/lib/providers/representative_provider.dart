import 'package:flutter/material.dart';
import '../core/network/api_service.dart';
import '../models/order.dart';
import '../models/user.dart';

class RepresentativeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<User> _retailers = [];
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<User> get retailers => _retailers;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeRetailerCount => _retailers.length;
  int get openOrderCount => _orders
      .where(
        (order) =>
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled,
      )
      .length;
  int get unpaidOrderCount =>
      _orders.where((order) => order.remainingBalance > 0).length;
  double get totalSales => _orders
      .where((order) => order.status != OrderStatus.cancelled)
      .fold(0.0, (sum, order) => sum + order.totalAmount);
  double get outstandingBalance =>
      _orders.fold(0.0, (sum, order) => sum + order.remainingBalance);

  List<Order> ordersForRetailer(String retailerId) =>
      _orders.where((order) => order.retailerId == retailerId).toList();

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        _retailers = _mockRetailers;
        _orders = _mockOrders;
      } else {
        final usersResponse = await _apiService.client.get(
          '/users',
          queryParameters: {'role': 'retailer', 'per_page': 100},
        );
        final ordersResponse = await _apiService.client.get(
          '/orders',
          queryParameters: {'per_page': 100},
        );

        _retailers = (usersResponse.data['data'] as List<dynamic>)
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .where((user) => user.role == UserRole.retailer)
            .toList();

        _orders = (ordersResponse.data['data'] as List<dynamic>)
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to load representative workspace: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> recordCashPayment({
    required Order order,
    required double amount,
    String? notes,
  }) async {
    _error = null;

    try {
      if (_apiService.mockMode) {
        _applyPayment(order.id, amount);
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.post(
        '/payments',
        data: {
          'order_id': order.id,
          'amount': amount,
          'method': 'cash',
          'notes': notes,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        _applyPayment(order.id, amount);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Failed to record cash payment: $e';
    }

    notifyListeners();
    return false;
  }

  void _applyPayment(String orderId, double amount) {
    _orders = _orders.map((order) {
      if (order.id != orderId) return order;
      final paidAmount = (order.paidAmount + amount).clamp(
        0.0,
        order.totalAmount,
      );
      final paymentStatus = paidAmount >= order.totalAmount
          ? PaymentStatus.paid
          : paidAmount > 0
          ? PaymentStatus.partiallyPaid
          : PaymentStatus.unpaid;
      return order.copyWith(
        paidAmount: paidAmount,
        paymentStatus: paymentStatus,
      );
    }).toList();
  }

  List<User> get _mockRetailers => [
    User(
      id: 'RET_REP_001',
      username: 'Atlas Corner Shop',
      email: 'atlas@bmp.com',
      role: UserRole.retailer,
      address: 'Central Market',
      latitude: 48.8566,
      longitude: 2.3522,
    ),
    User(
      id: 'RET_REP_002',
      username: 'North Mini Market',
      email: 'north@bmp.com',
      role: UserRole.retailer,
      address: 'North District',
    ),
  ];

  List<Order> get _mockOrders => [
    Order(
      id: 'REP_ORD_001',
      retailerId: 'RET_REP_001',
      retailerName: 'Atlas Corner Shop',
      items: const [],
      totalAmount: 420,
      status: OrderStatus.approved,
      paymentStatus: PaymentStatus.partiallyPaid,
      paidAmount: 120,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      deliveryAddress: 'Central Market',
    ),
    Order(
      id: 'REP_ORD_002',
      retailerId: 'RET_REP_002',
      retailerName: 'North Mini Market',
      items: const [],
      totalAmount: 180,
      status: OrderStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      deliveryAddress: 'North District',
    ),
  ];
}
