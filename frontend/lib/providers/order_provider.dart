import 'package:flutter/material.dart';
import '../models/order.dart';
import '../core/network/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrders(String retailerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (_orders.isEmpty) {
          _orders = _getMockOrders(retailerId);
        }
      } else {
        // Backend filters orders by auth token automatically
        final response = await _apiService.client.get('/orders');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;
          _orders = data
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      _error = 'Failed to load orders: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Order?> addOrder(Order order) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        _orders.insert(0, order);
        _isLoading = false;
        notifyListeners();
        return order;
      } else {
        // Create request payload matching StoreOrderRequest validation format
        final payload = {
          'items': order.items
              .map(
                (item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                },
              )
              .toList(),
          'delivery_address': order.deliveryAddress ?? 'Default Address',
          'notes': order.notes,
        };

        final response = await _apiService.client.post(
          '/orders',
          data: payload,
        );
        if (response.statusCode == 201) {
          final body = response.data;
          if (body['success'] == true) {
            final newOrder = Order.fromJson(
              body['data'] as Map<String, dynamic>,
            );
            _orders.insert(0, newOrder);
            _isLoading = false;
            notifyListeners();
            return newOrder;
          }
        }
      }
    } catch (e) {
      _error = 'Failed to place order: $e';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final order = _orders[index];

      // Map OrderStatus to backend string status
      String statusStr = 'pending';
      if (status == OrderStatus.approved) statusStr = 'confirmed';
      if (status == OrderStatus.outForDelivery) statusStr = 'out_for_delivery';
      if (status == OrderStatus.delivered) statusStr = 'delivered';
      if (status == OrderStatus.cancelled) statusStr = 'cancelled';

      try {
        if (!_apiService.mockMode) {
          await _apiService.client.put(
            '/orders/$orderId/status',
            data: {'status': statusStr, 'reason': 'Status updated via app.'},
          );
        }
        _orders[index] = order.copyWith(status: status);
        notifyListeners();
      } catch (e) {
        _error = 'Failed to update order status: $e';
        notifyListeners();
      }
    }
  }

  Future<void> recordPayment(String orderId, double amount) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final order = _orders[index];

      try {
        if (!_apiService.mockMode) {
          await _apiService.client.post(
            '/payments',
            data: {
              'order_id': orderId,
              'amount': amount,
              'method': 'cash',
              'notes': 'Recorded via app payment view.',
            },
          );
        }

        final double newPaidAmount = order.paidAmount + amount;
        PaymentStatus paymentStatus = PaymentStatus.partiallyPaid;

        if (newPaidAmount >= order.totalAmount) {
          paymentStatus = PaymentStatus.paid;
        } else if (newPaidAmount <= 0.0) {
          paymentStatus = PaymentStatus.unpaid;
        }

        _orders[index] = order.copyWith(
          paidAmount: newPaidAmount.clamp(0.0, order.totalAmount),
          paymentStatus: paymentStatus,
        );
        notifyListeners();
      } catch (e) {
        _error = 'Failed to record payment: $e';
        notifyListeners();
      }
    }
  }

  List<Order> _getMockOrders(String retailerId) {
    return [
      Order(
        id: 'ORD_9901',
        retailerId: retailerId,
        retailerName: 'Retailer Shop',
        items: [],
        totalAmount: 142.50,
        status: OrderStatus.delivered,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        assignedDistributorId: 'DST_001',
        assignedDistributorName: 'Distributor Cargo',
        paidAmount: 142.50,
      ),
      Order(
        id: 'ORD_9902',
        retailerId: retailerId,
        retailerName: 'Retailer Shop',
        items: [],
        totalAmount: 84.90,
        status: OrderStatus.outForDelivery,
        paymentStatus: PaymentStatus.partiallyPaid,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        assignedDistributorId: 'DST_001',
        assignedDistributorName: 'Distributor Cargo',
        paidAmount: 40.00,
      ),
      Order(
        id: 'ORD_9903',
        retailerId: retailerId,
        retailerName: 'Retailer Shop',
        items: [],
        totalAmount: 345.00,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now(),
        paidAmount: 0.0,
      ),
    ];
  }
}
