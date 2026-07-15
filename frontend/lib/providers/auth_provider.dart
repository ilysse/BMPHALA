import 'package:flutter/material.dart';
import '../models/user.dart';
import '../core/services/storage_service.dart';
import '../core/network/api_service.dart';
import '../core/services/notification_service.dart';
import 'package:dio/dio.dart';

class AuthProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final ApiService _apiService;

  AuthProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  User? _currentUser;
  bool _isLoading = false;
  bool _authConfigLoaded = false;
  bool _otpLoginEnabled = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get authConfigLoaded => _authConfigLoaded;
  bool get otpLoginEnabled => _otpLoginEnabled;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> loadAuthConfig() async {
    try {
      if (_apiService.mockMode) {
        _otpLoginEnabled = true;
      } else {
        final response = await _apiService.client.get('/auth/config');
        final body = response.data;
        _otpLoginEnabled =
            response.statusCode == 200 &&
            body is Map &&
            body['success'] == true &&
            body['data'] is Map &&
            body['data']['otp_login_enabled'] == true;
      }
    } catch (_) {
      // Keep OTP unavailable when its server-side status cannot be confirmed.
      _otpLoginEnabled = false;
    }

    _authConfigLoaded = true;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    // Note: Do not call notifyListeners() here synchronously because it runs during build
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_apiService.mockMode) {
        final userData = await _storageService.getUserData();
        if (userData['userId'] != null &&
            userData['username'] != null &&
            userData['role'] != null) {
          _currentUser = User(
            id: userData['userId']!,
            username: userData['username']!,
            email: '${userData['username']}@bmp.com',
            role: User.parseRole(userData['role']!),
          );
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        final response = await _apiService.client.get('/auth/me');
        if (response.statusCode == 200 && response.data['success'] == true) {
          _currentUser = User.fromJson(
            response.data['data'] as Map<String, dynamic>,
          );
          await _saveCurrentUser();
          await NotificationService.instance.syncToken();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _error = 'Auto login failed';
      await _storageService.clearAll();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _saveCurrentUser() async {
    if (_currentUser == null) return;
    await _storageService.saveUserData(
      userId: _currentUser!.id,
      username: _currentUser!.username,
      role: _currentUser!.roleName,
    );
  }

  Future<void> _applyAuthPayload(Map<String, dynamic> payload) async {
    _currentUser = User.fromJson(payload['user'] as Map<String, dynamic>);

    await _storageService.saveTokens(
      accessToken: payload['access_token'] as String,
      refreshToken: payload['refresh_token'] as String,
    );
    await _saveCurrentUser();
    await NotificationService.instance.syncToken();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (identifier.trim().isEmpty) {
        throw Exception('Please enter your email address or phone number.');
      }
      if (!identifier.contains('@') && identifier.trim().length < 8) {
        throw Exception('Please enter a valid phone number.');
      }
      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters.');
      }

      final response = await _apiService.client.post(
        '/auth/mobile-login',
        data: {'identifier': identifier.trim(), 'password': password},
      );

      final body = response.data;
      if (response.statusCode == 200 && body['success'] == true) {
        final payload = body['data'];
        await _applyAuthPayload(payload as Map<String, dynamic>);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception(body['message'] ?? 'Login failed.');
    } catch (e) {
      _error = _cleanError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> requestOtp({
    required String phone,
    required String channel,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadAuthConfig();
      if (!_otpLoginEnabled) {
        throw Exception('OTP login is disabled by the administrator.');
      }
      if (phone.trim().length < 8) {
        throw Exception('Enter a valid phone number.');
      }

      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.post(
        '/auth/otp/request',
        data: {'phone': phone.trim(), 'channel': channel},
      );

      final body = response.data;
      if (response.statusCode == 200 && body['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception(body['message'] ?? 'Unable to send OTP.');
    } catch (e) {
      _error = _cleanError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyOtp({
    required String phone,
    required String channel,
    required String code,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadAuthConfig();
      if (!_otpLoginEnabled) {
        throw Exception('OTP login is disabled by the administrator.');
      }
      if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
        throw Exception('Enter the 6-digit OTP code.');
      }

      if (_apiService.mockMode) {
        if (code.trim() != '123456') {
          throw Exception('Use 123456 for mock OTP.');
        }

        _currentUser = User(
          id: 'OTP_RET_001',
          username: 'OTP Retailer',
          email: 'otp-retailer@bmp.com',
          role: UserRole.retailer,
        );
        await _storageService.saveTokens(
          accessToken: 'mock_jwt_access_token_otp',
          refreshToken: 'mock_jwt_refresh_token_otp',
        );
        await _saveCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final response = await _apiService.client.post(
        '/auth/otp/verify',
        data: {'phone': phone.trim(), 'channel': channel, 'code': code.trim()},
      );

      final body = response.data;
      if (response.statusCode == 200 && body['success'] == true) {
        await _applyAuthPayload(body['data'] as Map<String, dynamic>);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception(body['message'] ?? 'OTP verification failed.');
    } catch (e) {
      _error = _cleanError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  String _cleanError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) return '${value.first}';
            if (value is String && value.isNotEmpty) return value;
          }
        }
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The server took too long to respond. Please try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Cannot reach the server. Check Wi-Fi and the backend address.';
      }
      if ((error.response?.statusCode ?? 0) >= 500) {
        return 'The server encountered an error. Please try again shortly.';
      }
      return 'Login request failed. Please check your information.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  Future<bool> onboardRetailer({
    required String shopName,
    required String email,
    required String password,
    required String phone,
    String? referralCode,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (shopName.isEmpty ||
          (email.trim().isEmpty && phone.trim().isEmpty) ||
          (phone.trim().isNotEmpty && phone.trim().length < 8) ||
          password.length < 8) {
        throw Exception('Please fill in all fields correctly.');
      }

      if (_apiService.mockMode) {
        await Future.delayed(const Duration(milliseconds: 1000));
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Use the register endpoint with referral_code
        final response = await _apiService.client.post(
          '/auth/register',
          data: {
            'name': shopName,
            'email': email.trim().isEmpty ? null : email.trim(),
            'password': password,
            'password_confirmation': password,
            'phone': phone.trim().isEmpty ? null : phone.trim(),
            'company_name': shopName,
            'referral_code': referralCode,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
          },
        );

        final body = response.data;
        if (response.statusCode == 201 && body['success'] == true) {
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          throw Exception(body['message'] ?? 'Registration failed.');
        }
      }
    } catch (e) {
      _error = _cleanError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    if (!_apiService.mockMode) {
      try {
        await NotificationService.instance.unregisterToken();
        await _apiService.client.post('/auth/logout');
      } catch (_) {
        // Ignore logout API errors, just clear local state
      }
    }

    await _storageService.clearAll();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
