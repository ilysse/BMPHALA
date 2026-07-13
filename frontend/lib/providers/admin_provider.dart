import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../core/network/api_service.dart';

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Dashboard Metrics
  double _totalSales = 0.00;
  int _activeRetailersCount = 0;
  int _totalOrdersCount = 0;
  double _outstandingPayments = 0.00;

  // Lists
  List<Order> _pendingApprovals = [];
  List<User> _distributors = [];
  List<User> _salesReps = [];
  List<User> _cashCollectors = [];
  List<Order> _allOrders = [];
  List<User> _allRetailers = [];
  List<dynamic> _salesTrend = [];
  bool _isDashboardLoading = false;
  bool _isApprovalsLoading = false;
  bool _isDistributorsLoading = false;
  bool _isSalesRepsLoading = false;
  String? _error;
  DateTime? _dashboardLoadedAt;

  // Getters
  double get totalSales => _totalSales;
  int get activeRetailersCount => _activeRetailersCount;
  int get totalOrdersCount => _totalOrdersCount;
  double get outstandingPayments => _outstandingPayments;
  List<dynamic> get salesTrend => _salesTrend;
  List<Order> get pendingApprovals => _pendingApprovals;
  List<User> get distributors => _distributors;
  List<User> get salesReps => _salesReps;
  List<User> get cashCollectors => _cashCollectors;
  List<Order> get allOrders => _allOrders;
  List<User> get allRetailers => _allRetailers;
  bool get isLoading =>
      _isDashboardLoading ||
      _isApprovalsLoading ||
      _isDistributorsLoading ||
      _isSalesRepsLoading;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get isApprovalsLoading => _isApprovalsLoading;
  String? get error => _error;

  Future<void> fetchDashboardMetrics({bool force = false}) async {
    if (!force &&
        _dashboardLoadedAt != null &&
        DateTime.now().difference(_dashboardLoadedAt!) <
            const Duration(minutes: 2)) {
      return;
    }
    _isDashboardLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _totalSales = 245980.00;
        _activeRetailersCount = 142;
        _totalOrdersCount = 845;
        _outstandingPayments = 38450.00;
        _salesTrend = [
          {'date': 'Jan', 'sales': 15000.0},
          {'date': 'Feb', 'sales': 28000.0},
          {'date': 'Mar', 'sales': 22000.0},
          {'date': 'Apr', 'sales': 45000.0},
          {'date': 'May', 'sales': 38000.0},
          {'date': 'Jun', 'sales': 54000.0},
        ];
        // Mock lists for dashboard click interactions
        _allRetailers = [
          User(
            id: 'RET_001',
            username: 'Corner Market Inc.',
            email: 'corner@bmp.com',
            role: UserRole.retailer,
          ),
          User(
            id: 'RET_002',
            username: 'Quick Stop Groceries',
            email: 'quick@bmp.com',
            role: UserRole.retailer,
          ),
          User(
            id: 'RET_003',
            username: 'Metro Supermarket',
            email: 'metro@bmp.com',
            role: UserRole.retailer,
          ),
        ];
        _allOrders = [
          Order(
            id: 'ORD_2001',
            retailerId: 'RET_001',
            retailerName: 'Corner Market Inc.',
            items: [],
            totalAmount: 136.50,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.unpaid,
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          ),
          Order(
            id: 'ORD_2002',
            retailerId: 'RET_002',
            retailerName: 'Quick Stop Groceries',
            items: [],
            totalAmount: 159.90,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.partiallyPaid,
            createdAt: DateTime.now().subtract(const Duration(hours: 24)),
            paidAmount: 50.0,
          ),
          Order(
            id: 'ORD_2003',
            retailerId: 'RET_003',
            retailerName: 'Metro Supermarket',
            items: [],
            totalAmount: 159.80,
            status: OrderStatus.approved,
            paymentStatus: PaymentStatus.paid,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            paidAmount: 159.80,
          ),
        ];
      } else {
        final response = await _apiService.client.get('/reports/sales');

        if (response.statusCode == 200) {
          final data = response.data['data'] as Map<String, dynamic>;
          final List<dynamic> recentOrders =
              data['recent_orders'] as List<dynamic>? ?? [];

          _totalSales = _toDouble(data['gross_sales']);
          _activeRetailersCount =
              _toInt(data['active_retailers_count']) ??
              _toInt(data['ordering_retailers_count']) ??
              0;
          _totalOrdersCount = _toInt(data['total_orders']) ?? 0;
          _outstandingPayments = _toDouble(data['outstanding_balance']);
          _salesTrend = data['daily_sales'] as List<dynamic>? ?? [];
          _allOrders = recentOrders
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();

          _dashboardLoadedAt = DateTime.now();
        }
      }
    } catch (e) {
      _error = 'Failed to fetch dashboard metrics: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
  }

  Future<void> fetchPendingApprovals() async {
    _isApprovalsLoading = true;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (_pendingApprovals.isEmpty) {
          _pendingApprovals = _getMockPendingApprovals();
        }
      } else {
        // Fetch pending orders from standard /orders endpoint and filter locally
        final response = await _apiService.client.get('/orders');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;
          final List<Order> allOrders = data
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();
          _pendingApprovals = allOrders
              .where((o) => o.status == OrderStatus.pending)
              .toList();
        }
      }
    } catch (e) {
      _error = 'Failed to load pending approvals: $e';
    }

    _isApprovalsLoading = false;
    notifyListeners();
  }

  Future<void> fetchDistributors() async {
    _isDistributorsLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        _distributors = [
          User(
            id: 'DST_001',
            username: 'Distributor Cargo',
            email: 'distributor@bmp.com',
            role: UserRole.distributor,
          ),
          User(
            id: 'DST_002',
            username: 'Swift Delivery Ltd.',
            email: 'swift@bmp.com',
            role: UserRole.distributor,
          ),
          User(
            id: 'DST_003',
            username: 'Express Haulers',
            email: 'express@bmp.com',
            role: UserRole.distributor,
          ),
        ];
      } else {
        final response = await _apiService.client.get('/users');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;
          final List<User> allUsers = data
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
          _distributors = allUsers
              .where((u) => u.role == UserRole.distributor)
              .toList();
        }
      }
    } catch (e) {
      _error = 'Failed to load distributors: $e';
    }

    _isDistributorsLoading = false;
    notifyListeners();
  }

  Future<void> fetchSalesReps() async {
    _isSalesRepsLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        _salesReps = [
          User(
            id: 'REP_001',
            username: 'Alex Johnson',
            email: 'alex@bmp.com',
            role: UserRole.salesRep,
            salesPerformance: 85400.00,
            salesOrderCount: 12,
            assignedRetailerCount: 8,
            referralCode: 'REF_ALEX_99',
          ),
          User(
            id: 'REP_002',
            username: 'Sarah Connor',
            email: 'sarah@bmp.com',
            role: UserRole.salesRep,
            salesPerformance: 92100.00,
            salesOrderCount: 14,
            assignedRetailerCount: 9,
            referralCode: 'REF_SARAH_88',
          ),
          User(
            id: 'REP_003',
            username: 'David Miller',
            email: 'david@bmp.com',
            role: UserRole.salesRep,
            salesPerformance: 68480.00,
            salesOrderCount: 9,
            assignedRetailerCount: 6,
            referralCode: 'REF_DAVID_77',
          ),
        ];
      } else {
        final response = await _apiService.client.get('/users');
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data['data'] as List<dynamic>;
          final List<User> allUsers = data
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
          _salesReps = allUsers
              .where((u) => u.role == UserRole.salesRep)
              .toList();
          _allRetailers = allUsers
              .where((u) => u.role == UserRole.retailer)
              .toList();
          _cashCollectors = allUsers
              .where(
                (u) =>
                    u.roleName == 'distributor' ||
                    u.roleName == 'sales_rep' ||
                    u.roleName == 'admin',
              )
              .toList();
          final ordersResponse = await _apiService.client.get('/orders');
          if (ordersResponse.statusCode == 200) {
            final List<dynamic> ordersData =
                ordersResponse.data['data'] as List<dynamic>;
            _allOrders = ordersData
                .map((json) => Order.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (e) {
      _error = 'Failed to load sales reps: $e';
    }

    _isSalesRepsLoading = false;
    notifyListeners();
  }

  Future<bool> approveOrder(
    String orderId,
    String distributorId,
    String distributorName,
  ) async {
    _isDashboardLoading = true;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _pendingApprovals.removeWhere((o) => o.id == orderId);
        _totalOrdersCount += 1;
        _isDashboardLoading = false;
        notifyListeners();
        return true;
      } else {
        // Confirm first, then assignment can move the order into the assigned state.
        final approveResponse = await _apiService.client.put(
          '/orders/$orderId/status',
          data: {'status': 'confirmed', 'reason': 'Order approved by admin.'},
        );

        final assignResponse = await _apiService.client.post(
          '/orders/$orderId/assign',
          data: {'distributor_id': distributorId},
        );

        if (assignResponse.statusCode == 200 &&
            approveResponse.statusCode == 200) {
          _pendingApprovals.removeWhere((o) => o.id == orderId);
          _isDashboardLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _error = 'Failed to approve order: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> rejectOrder(String orderId) async {
    _isDashboardLoading = true;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _pendingApprovals.removeWhere((o) => o.id == orderId);
        _isDashboardLoading = false;
        notifyListeners();
        return true;
      } else {
        final response = await _apiService.client.post(
          '/orders/$orderId/cancel',
        );
        if (response.statusCode == 200) {
          _pendingApprovals.removeWhere((o) => o.id == orderId);
          _isDashboardLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _error = 'Failed to reject order: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> createUserAccount({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String? address,
    double? latitude,
    double? longitude,
    bool canCollectCash = false,
  }) async {
    _isDashboardLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        UserRole frontRole = UserRole.retailer;
        if (role == 'admin') frontRole = UserRole.admin;
        if (role == 'distributor') frontRole = UserRole.distributor;
        if (role == 'sales_rep') frontRole = UserRole.salesRep;

        final newUser = User(
          id: '${role.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}',
          username: name,
          email: email,
          role: frontRole,
          salesPerformance: 0.0,
          address: address,
          latitude: latitude,
          longitude: longitude,
          canCollectCash: canCollectCash,
          referralCode: role == 'sales_rep'
              ? 'REF_${name.toUpperCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}'
              : null,
        );
        if (role == 'sales_rep') {
          _salesReps.add(newUser);
        } else if (role == 'distributor') {
          _distributors.add(newUser);
        } else if (role == 'retailer') {
          _allRetailers.add(newUser);
        }
        if (role == 'sales_rep' || role == 'distributor' || role == 'admin') {
          _cashCollectors.add(newUser);
        }
        _isDashboardLoading = false;
        notifyListeners();
        return true;
      } else {
        final response = await _apiService.client.post(
          '/users',
          data: {
            'name': name,
            'email': email,
            'password': password,
            'role': role,
            'phone': phone,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'can_collect_cash': canCollectCash,
          },
        );

        if (response.statusCode == 201) {
          final body = response.data;
          if (body['success'] == true) {
            final User newUser = User.fromJson(
              body['data'] as Map<String, dynamic>,
            );
            if (role == 'sales_rep') {
              _salesReps.add(newUser);
            } else if (role == 'distributor') {
              _distributors.add(newUser);
            } else if (role == 'retailer') {
              _allRetailers.add(newUser);
            }
            if (role == 'sales_rep' ||
                role == 'distributor' ||
                role == 'admin') {
              _cashCollectors.add(newUser);
            }
            _isDashboardLoading = false;
            notifyListeners();
            return true;
          }
        }
      }
    } catch (e) {
      _error = 'Failed to create user account: $e';
    }

    _isDashboardLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateCashCollectionPermission(User user, bool enabled) async {
    _error = null;

    try {
      if (_apiService.mockMode) {
        final updated = user.copyWith(canCollectCash: enabled);
        _replaceUser(updated);
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.put(
        '/users/${user.id}/cash-collection',
        data: {'can_collect_cash': enabled},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updated = User.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
        _replaceUser(updated);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Failed to update cash collection access: $e';
    }

    notifyListeners();
    return false;
  }

  Future<bool> updateRepresentativeFeatures(
    User user,
    Map<String, bool> features,
  ) async {
    _error = null;

    try {
      if (_apiService.mockMode) {
        _replaceUser(user.copyWith(representativeFeatures: features));
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.put(
        '/users/${user.id}/representative-features',
        data: {'representative_features': features},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updated = User.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
        _replaceUser(updated);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Failed to update representative features: $e';
    }

    notifyListeners();
    return false;
  }

  Future<bool> updateUserPassword(User user, String password) async {
    _error = null;

    try {
      if (_apiService.mockMode) {
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.put(
        '/users/${user.id}/password',
        data: {'password': password, 'password_confirmation': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Failed to update password: $e';
    }

    notifyListeners();
    return false;
  }

  List<User> retailersForRep(User rep) {
    return _allRetailers
        .where((retailer) => retailer.referredBy == rep.id)
        .toList();
  }

  List<Order> countedOrdersForRep(User rep) {
    final retailerIds = retailersForRep(
      rep,
    ).map((retailer) => retailer.id).toSet();
    return _allOrders
        .where(
          (order) =>
              retailerIds.contains(order.retailerId) &&
              order.status != OrderStatus.cancelled,
        )
        .toList();
  }

  void _replaceUser(User updated) {
    void replaceIn(List<User> users) {
      final index = users.indexWhere((user) => user.id == updated.id);
      if (index != -1) users[index] = updated;
    }

    replaceIn(_salesReps);
    replaceIn(_distributors);
    replaceIn(_cashCollectors);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<Order> _getMockPendingApprovals() {
    return [
      Order(
        id: 'ORD_3001',
        retailerId: 'RET_101',
        retailerName: 'Sunset Retailers',
        items: [],
        totalAmount: 420.50,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Order(
        id: 'ORD_3002',
        retailerId: 'RET_102',
        retailerName: 'Family Mart',
        items: [],
        totalAmount: 185.00,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Order(
        id: 'ORD_3003',
        retailerId: 'RET_103',
        retailerName: 'Value Store',
        items: [],
        totalAmount: 612.00,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }
}
