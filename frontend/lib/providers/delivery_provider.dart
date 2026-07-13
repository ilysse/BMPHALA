import 'package:flutter/material.dart';
import '../models/delivery.dart';
import '../models/order.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../core/network/api_service.dart';
import 'dart:typed_data';

class DeliveryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<DeliveryTask> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<DeliveryTask> get tasks => _tasks;
  List<DeliveryTask> get pendingTasks =>
      _tasks.where((t) => t.status == DeliveryStatus.pending).toList();
  List<DeliveryTask> get activeTasks =>
      _tasks.where((t) => t.status == DeliveryStatus.inTransit).toList();
  List<DeliveryTask> get completedTasks =>
      _tasks.where((t) => t.status == DeliveryStatus.completed).toList();

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTasks(String distributorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (_tasks.isEmpty) {
          _tasks = _getMockTasks();
        }
      } else {
        // Distributor fetches assigned orders via the main /orders endpoint
        final response = await _apiService.client.get('/orders');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;

          _tasks = data.map((jsonOrder) {
            final order = Order.fromJson(jsonOrder as Map<String, dynamic>);

            // Map order status to delivery status
            DeliveryStatus delStatus = DeliveryStatus.pending;
            if (order.status == OrderStatus.outForDelivery) {
              delStatus = DeliveryStatus.inTransit;
            } else if (order.status == OrderStatus.delivered) {
              delStatus = DeliveryStatus.completed;
            } else if (order.status == OrderStatus.cancelled) {
              delStatus = DeliveryStatus.failed;
            }

            return DeliveryTask(
              id: order.id,
              order: order,
              latitude: order.deliveryLatitude ?? 0.0,
              longitude: order.deliveryLongitude ?? 0.0,
              status: delStatus,
              signatureData: order.deliverySignatureUrl,
              photoPath: order.deliveryPhotoUrl,
              collectedAmount: order.paidAmount,
              completedAt: order.status == OrderStatus.delivered
                  ? DateTime.now()
                  : null,
            );
          }).toList();
        }
      }
    } catch (e) {
      _error = 'Failed to load delivery tasks: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> startDelivery(String taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        if (!_apiService.mockMode) {
          // Transition order status from assigned into transit on backend.
          await _apiService.client.put(
            '/orders/${task.order.id}/status',
            data: {
              'status': 'in_transit',
              'reason': 'Distributor started delivery run.',
            },
          );
        }
        _tasks[index] = task.copyWith(
          status: DeliveryStatus.inTransit,
          order: task.order.copyWith(status: OrderStatus.outForDelivery),
        );
      }
    } catch (e) {
      _error = 'Failed to start delivery: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> completeDelivery(
    String taskId, {
    required Uint8List signatureBytes,
    required Uint8List photoBytes,
    required double collectedAmount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        String signaturePath = 'mock-signature.png';
        String photoPath = 'mock-photo.jpg';

        if (!_apiService.mockMode) {
          final uploaded = await Future.wait([
            _apiService.uploadImageBytes(
              signatureBytes,
              'signature-${task.order.id}.png',
            ),
            _apiService.uploadImageBytes(
              photoBytes,
              'delivery-${task.order.id}.jpg',
            ),
          ]);
          if (uploaded[0] == null || uploaded[1] == null) {
            throw Exception('Unable to upload delivery proof. Please retry.');
          }
          signaturePath = uploaded[0]!;
          photoPath = uploaded[1]!;

          // 1. Mark order as delivered
          await _apiService.client.post(
            '/orders/${task.order.id}/deliver',
            data: {
              'signature_url': signaturePath,
              'photo_url': photoPath,
              'notes': 'Delivery completed by distributor.',
            },
          );

          // 2. If distributor collected cash, record payment
          if (collectedAmount > 0) {
            await _apiService.client.post(
              '/payments',
              data: {
                'order_id': task.order.id,
                'amount': collectedAmount,
                'method': 'cash',
                'notes': 'Collected on delivery.',
              },
            );
          }
        }

        // Update local state
        final updatedOrder = task.order.copyWith(
          status: OrderStatus.delivered,
          paidAmount: (task.order.paidAmount + collectedAmount).clamp(
            0.0,
            task.order.totalAmount,
          ),
          paymentStatus:
              (task.order.paidAmount + collectedAmount) >=
                  task.order.totalAmount
              ? PaymentStatus.paid
              : PaymentStatus.partiallyPaid,
        );

        _tasks[index] = task.copyWith(
          status: DeliveryStatus.completed,
          signatureData: signaturePath,
          photoPath: photoPath,
          collectedAmount: collectedAmount,
          completedAt: DateTime.now(),
          order: updatedOrder,
        );
      }
    } catch (e) {
      _error = 'Failed to complete delivery: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> failDelivery(String taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        if (!_apiService.mockMode) {
          // Transition order status to cancelled on backend
          await _apiService.client.put(
            '/orders/${task.order.id}/status',
            data: {
              'status': 'cancelled',
              'reason': 'Delivery failed / customer not reachable.',
            },
          );
        }
        _tasks[index] = task.copyWith(
          status: DeliveryStatus.failed,
          order: task.order.copyWith(status: OrderStatus.cancelled),
        );
      }
    } catch (e) {
      _error = 'Failed to fail delivery: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  List<DeliveryTask> _getMockTasks() {
    return [
      DeliveryTask(
        id: 'DEL_101',
        order: Order(
          id: 'ORD_2001',
          retailerId: 'RET_001',
          retailerName: 'Corner Market Inc.',
          items: [
            CartItem(
              product: Product(
                id: 'PROD_001',
                name: 'Premium Roasted Coffee Beans',
                sku: 'BEV-COF-001',
                price: 18.50,
                category: 'Beverages',
                stock: 10,
                imageUrl:
                    'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500&q=80',
                description: '',
              ),
              quantity: 5,
            ),
            CartItem(
              product: Product(
                id: 'PROD_007',
                name: 'Extra Virgin Olive Oil (1L)',
                sku: 'PKG-OIL-007',
                price: 22.00,
                category: 'Packaged Foods',
                stock: 10,
                imageUrl:
                    'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500&q=80',
                description: '',
              ),
              quantity: 2,
            ),
          ],
          totalAmount: 136.50,
          status: OrderStatus.approved,
          paymentStatus: PaymentStatus.unpaid,
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          paidAmount: 0.0,
        ),
        latitude: 6.4281,
        longitude: 3.4219,
        status: DeliveryStatus.pending,
      ),
      DeliveryTask(
        id: 'DEL_102',
        order: Order(
          id: 'ORD_2002',
          retailerId: 'RET_002',
          retailerName: 'Quick Stop Groceries',
          items: [
            CartItem(
              product: Product(
                id: 'PROD_005',
                name: 'Basmati Rice (5kg)',
                sku: 'GRN-RIC-005',
                price: 15.99,
                category: 'Grains & Pasta',
                stock: 10,
                imageUrl:
                    'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500&q=80',
                description: '',
              ),
              quantity: 10,
            ),
          ],
          totalAmount: 159.90,
          status: OrderStatus.approved,
          paymentStatus: PaymentStatus.partiallyPaid,
          createdAt: DateTime.now().subtract(const Duration(hours: 24)),
          paidAmount: 50.0,
        ),
        latitude: 6.4385,
        longitude: 3.4520,
        status: DeliveryStatus.pending,
      ),
      DeliveryTask(
        id: 'DEL_103',
        order: Order(
          id: 'ORD_2003',
          retailerId: 'RET_003',
          retailerName: 'Metro Supermarket',
          items: [
            CartItem(
              product: Product(
                id: 'PROD_009',
                name: 'Herbal Body Wash',
                sku: 'HYG-WSH-009',
                price: 7.99,
                category: 'Hygiene',
                stock: 10,
                imageUrl:
                    'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?w=500&q=80',
                description: '',
              ),
              quantity: 20,
            ),
          ],
          totalAmount: 159.80,
          status: OrderStatus.approved,
          paymentStatus: PaymentStatus.paid,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          paidAmount: 159.80,
        ),
        latitude: 6.4491,
        longitude: 3.4150,
        status: DeliveryStatus.pending,
      ),
    ];
  }
}
