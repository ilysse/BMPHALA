import 'order.dart';

enum DeliveryStatus { pending, inTransit, completed, failed }

class DeliveryTask {
  final String id;
  final Order order;
  final double latitude;
  final double longitude;
  final DeliveryStatus status;
  final String? signatureData;
  final String? photoPath;
  final double collectedAmount;
  final DateTime? completedAt;

  DeliveryTask({
    required this.id,
    required this.order,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.signatureData,
    this.photoPath,
    this.collectedAmount = 0.0,
    this.completedAt,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      id: json['id'] as String,
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: _parseDeliveryStatus((json['status'] ?? 'pending') as String),
      signatureData:
          (json['signature_data'] ?? json['signatureData']) as String?,
      photoPath: (json['photo_path'] ?? json['photoPath']) as String?,
      collectedAmount:
          ((json['collected_amount'] ?? json['collectedAmount'] ?? 0.0) as num)
              .toDouble(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : (json['completedAt'] != null
                ? DateTime.parse(json['completedAt'] as String)
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order.toJson(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status.name,
      'signature_data': signatureData,
      'photo_path': photoPath,
      'collected_amount': collectedAmount,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  DeliveryTask copyWith({
    String? id,
    Order? order,
    double? latitude,
    double? longitude,
    DeliveryStatus? status,
    String? signatureData,
    String? photoPath,
    double? collectedAmount,
    DateTime? completedAt,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      order: order ?? this.order,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      signatureData: signatureData ?? this.signatureData,
      photoPath: photoPath ?? this.photoPath,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static DeliveryStatus _parseDeliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'intransit':
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'completed':
      case 'delivered':
        return DeliveryStatus.completed;
      case 'failed':
      case 'cancelled':
        return DeliveryStatus.failed;
      default:
        return DeliveryStatus.pending;
    }
  }
}
