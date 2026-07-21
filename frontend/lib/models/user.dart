enum UserRole { retailer, distributor, salesRep, admin }

class User {
  final String id;
  final String username;
  final String email;
  final UserRole role;
  final String status;
  final String? phone;
  final String? companyId;
  final String? referralCode; // For retailers
  final String? referredBy; // For retailers onboarding
  final double? salesPerformance; // For Sales Reps
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool canCollectCash;
  final Map<String, bool> representativeFeatures;
  final int? salesOrderCount;
  final int? assignedRetailerCount;
  final String roleName;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.status = 'active',
    this.phone,
    this.companyId,
    this.referralCode,
    this.referredBy,
    this.salesPerformance,
    this.latitude,
    this.longitude,
    this.address,
    this.canCollectCash = false,
    Map<String, bool>? representativeFeatures,
    this.salesOrderCount,
    this.assignedRetailerCount,
    String? roleName,
  }) : representativeFeatures =
           representativeFeatures ??
           const {
             'dashboard': true,
             'retailers': true,
             'orders': true,
             'onboarding': true,
           },
       roleName = roleName ?? _roleToApiName(role);

  /// Parse from backend API response (snake_case fields)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: (json['name'] ?? json['username'] ?? '') as String,
      email: json['email']?.toString() ?? '',
      role: _parseRole((json['role'] ?? 'retailer') as String),
      roleName: (json['role'] ?? 'retailer') as String,
      status: (json['status'] ?? 'active') as String,
      phone: json['phone'] as String?,
      companyId: json['company_id'] as String?,
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
      salesPerformance: json['sales_performance'] == null
          ? null
          : _toDouble(json['sales_performance']),
      latitude: _toNullableDouble(json['latitude']),
      longitude: _toNullableDouble(json['longitude']),
      address: json['address'] as String?,
      canCollectCash: json['can_collect_cash'] == true,
      representativeFeatures: _parseRepresentativeFeatures(
        json['representative_features'],
      ),
      salesOrderCount: _toNullableInt(json['sales_order_count']),
      assignedRetailerCount: _toNullableInt(json['assigned_retailer_count']),
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, bool> _parseRepresentativeFeatures(dynamic value) {
    final defaults = {
      'dashboard': true,
      'retailers': true,
      'orders': true,
      'onboarding': true,
    };

    if (value is Map) {
      return {
        for (final entry in defaults.entries)
          entry.key: value[entry.key] is bool
              ? value[entry.key] as bool
              : entry.value,
      };
    }

    return defaults;
  }

  bool featureEnabled(String key) => representativeFeatures[key] ?? true;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': username,
      'email': email,
      'role': roleName,
      'status': status,
      'phone': phone,
      'company_id': companyId,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'sales_performance': salesPerformance,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'can_collect_cash': canCollectCash,
      'representative_features': representativeFeatures,
      'sales_order_count': salesOrderCount,
      'assigned_retailer_count': assignedRetailerCount,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    UserRole? role,
    String? status,
    String? phone,
    String? companyId,
    String? referralCode,
    String? referredBy,
    double? salesPerformance,
    double? latitude,
    double? longitude,
    String? address,
    bool? canCollectCash,
    Map<String, bool>? representativeFeatures,
    int? salesOrderCount,
    int? assignedRetailerCount,
    String? roleName,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      companyId: companyId ?? this.companyId,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      salesPerformance: salesPerformance ?? this.salesPerformance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      canCollectCash: canCollectCash ?? this.canCollectCash,
      representativeFeatures:
          representativeFeatures ?? this.representativeFeatures,
      salesOrderCount: salesOrderCount ?? this.salesOrderCount,
      assignedRetailerCount:
          assignedRetailerCount ?? this.assignedRetailerCount,
      roleName: roleName ?? this.roleName,
    );
  }

  static UserRole parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'retailer':
        return UserRole.retailer;
      case 'distributor':
        return UserRole.distributor;
      case 'sales_rep':
        return UserRole.salesRep;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.retailer;
    }
  }

  static UserRole _parseRole(String roleStr) => parseRole(roleStr);

  static String _roleToApiName(UserRole role) {
    switch (role) {
      case UserRole.retailer:
        return 'retailer';
      case UserRole.distributor:
        return 'distributor';
      case UserRole.salesRep:
        return 'sales_rep';
      case UserRole.admin:
        return 'admin';
    }
  }
}
