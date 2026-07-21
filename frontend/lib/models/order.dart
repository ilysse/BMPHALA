import 'cart.dart';
import 'product.dart';

enum OrderStatus { pending, approved, outForDelivery, delivered, cancelled }

enum PaymentStatus { unpaid, partiallyPaid, paid }

class Order {
  final String id;
  final String retailerId;
  final String retailerName;
  final List<CartItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final String? assignedDistributorId;
  final String? assignedDistributorName;
  final double paidAmount;
  final String? orderNumber;
  final String? deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliverySignatureUrl;
  final String? deliveryPhotoUrl;
  final String? notes;
  final DateTime? expectedDeliveryAt;
  final DateTime? actualDeliveryAt;

  Order({
    required this.id,
    required this.retailerId,
    required this.retailerName,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.assignedDistributorId,
    this.assignedDistributorName,
    this.paidAmount = 0.0,
    this.orderNumber,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliverySignatureUrl,
    this.deliveryPhotoUrl,
    this.notes,
    this.expectedDeliveryAt,
    this.actualDeliveryAt,
  });

  double get remainingBalance => totalAmount - paidAmount;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse retailer info
    String retId = '';
    String retName = 'Unknown Retailer';
    if (json['retailer'] != null && json['retailer'] is Map) {
      retId = (json['retailer']['id'] ?? '') as String;
      retName = (json['retailer']['name'] ?? 'Unknown Retailer') as String;
    } else if (json['customer'] != null && json['customer'] is Map) {
      retId = (json['customer']['id'] ?? '') as String;
      retName = (json['customer']['name'] ?? 'Unknown Retailer') as String;
    } else {
      retId = (json['retailer_id'] ?? json['retailerId'] ?? '') as String;
      retName = (json['retailerName'] ?? 'Retailer') as String;
    }

    // Parse distributor info
    String? distId;
    String? distName;
    if (json['distributor'] != null && json['distributor'] is Map) {
      distId = json['distributor']['id'] as String?;
      distName = json['distributor']['name'] as String?;
    } else {
      distId =
          json['distributor_id'] as String? ??
          json['assignedDistributorId'] as String?;
      distName = json['assignedDistributorName'] as String?;
    }

    // Parse items safely, mapping backend OrderItemResource to CartItem
    List<CartItem> parsedItems = [];
    if (json['items'] != null) {
      parsedItems = (json['items'] as List<dynamic>).map((item) {
        final map = item as Map<String, dynamic>;
        if (map.containsKey('product_id') || map.containsKey('productId')) {
          final prodId =
              (map['product_id'] ?? map['productId'] ?? '') as String;
          final prodName =
              (map['product_name'] ?? map['productName'] ?? 'Product')
                  as String;
          final unitPrice = _toDouble(map['unit_price'] ?? map['unitPrice']);
          return CartItem(
            product: Product(
              id: prodId,
              name: prodName,
              sku: '',
              price: unitPrice,
              category: '',
              stock: 0,
              imageUrl: 'https://via.placeholder.com/150',
              description: '',
            ),
            quantity: (map['quantity'] ?? 1) as int,
          );
        }
        return CartItem.fromJson(map);
      }).toList();
    }

    final retailerMap = json['retailer'] is Map
        ? json['retailer'] as Map
        : (json['customer'] is Map ? json['customer'] as Map : null);

    return Order(
      id: json['id'] as String,
      retailerId: retId,
      retailerName: retName,
      items: parsedItems,
      totalAmount: _toDouble(
        json['grand_total'] ?? json['total_amount'] ?? json['totalAmount'],
      ),
      status: _parseOrderStatus((json['status'] ?? 'pending') as String),
      paymentStatus: _parsePaymentStatus(
        (json['payment_status'] ?? json['paymentStatus'] ?? 'unpaid') as String,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now()),
      assignedDistributorId: distId,
      assignedDistributorName: distName,
      paidAmount: _toDouble(json['paid_amount'] ?? json['paidAmount']),
      orderNumber: (json['order_number'] ?? json['orderNumber']) as String?,
      deliveryAddress:
          (json['delivery_address'] ??
                  json['deliveryAddress'] ??
                  retailerMap?['address'])
              as String?,
      deliveryLatitude: _toNullableDouble(
        json['delivery_latitude'] ??
            json['deliveryLatitude'] ??
            retailerMap?['latitude'],
      ),
      deliveryLongitude: _toNullableDouble(
        json['delivery_longitude'] ??
            json['deliveryLongitude'] ??
            retailerMap?['longitude'],
      ),
      deliverySignatureUrl:
          (json['delivery_signature_url'] ?? json['deliverySignatureUrl'])
              as String?,
      deliveryPhotoUrl:
          (json['delivery_photo_url'] ?? json['deliveryPhotoUrl']) as String?,
      notes: json['notes'] as String?,
      expectedDeliveryAt: json['expected_delivery_at'] != null
          ? DateTime.tryParse(json['expected_delivery_at'] as String)
          : null,
      actualDeliveryAt: json['actual_delivery_at'] != null
          ? DateTime.tryParse(json['actual_delivery_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'retailer_id': retailerId,
      'retailerName': retailerName,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'created_at': createdAt.toIso8601String(),
      'distributor_id': assignedDistributorId,
      'assignedDistributorName': assignedDistributorName,
      'paid_amount': paidAmount,
      'order_number': orderNumber,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_signature_url': deliverySignatureUrl,
      'delivery_photo_url': deliveryPhotoUrl,
      'notes': notes,
      'expected_delivery_at': expectedDeliveryAt?.toIso8601String(),
      'actual_delivery_at': actualDeliveryAt?.toIso8601String(),
    };
  }

  Order copyWith({
    String? id,
    String? retailerId,
    String? retailerName,
    List<CartItem>? items,
    double? totalAmount,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    String? assignedDistributorId,
    String? assignedDistributorName,
    double? paidAmount,
    String? orderNumber,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliverySignatureUrl,
    String? deliveryPhotoUrl,
    String? notes,
    DateTime? expectedDeliveryAt,
    DateTime? actualDeliveryAt,
  }) {
    return Order(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      retailerName: retailerName ?? this.retailerName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      assignedDistributorId:
          assignedDistributorId ?? this.assignedDistributorId,
      assignedDistributorName:
          assignedDistributorName ?? this.assignedDistributorName,
      paidAmount: paidAmount ?? this.paidAmount,
      orderNumber: orderNumber ?? this.orderNumber,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliverySignatureUrl: deliverySignatureUrl ?? this.deliverySignatureUrl,
      deliveryPhotoUrl: deliveryPhotoUrl ?? this.deliveryPhotoUrl,
      notes: notes ?? this.notes,
      expectedDeliveryAt: expectedDeliveryAt ?? this.expectedDeliveryAt,
      actualDeliveryAt: actualDeliveryAt ?? this.actualDeliveryAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
      case 'processing':
      case 'assigned':
      case 'approved':
        return OrderStatus.approved;
      case 'in_transit':
      case 'out_for_delivery':
      case 'outfordelivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'returned':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'partially_paid':
      case 'partiallypaid':
      case 'partial':
        return PaymentStatus.partiallyPaid;
      case 'paid':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.unpaid;
    }
  }
}
