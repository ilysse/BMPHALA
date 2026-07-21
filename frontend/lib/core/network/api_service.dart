import 'dart:async';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final StorageService _storageService = StorageService();

  // Set mockMode to false to run against the live Laravel backend
  // Set to true to run in offline/standalone mock mode
  bool mockMode = false;

  // Override with --dart-define=BMP_API_BASE_URL=http://YOUR_LAN_IP:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'BMP_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Resolves uploaded image paths against the same host used by the API.
  static String publicImageUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) return input;

    final apiUri = Uri.parse(baseUrl);
    final origin = apiUri.replace(path: '', query: null, fragment: null);
    final parsed = Uri.tryParse(input);

    if (parsed != null && parsed.hasScheme) {
      final isLoopback =
          parsed.host == 'localhost' ||
          parsed.host == '127.0.0.1' ||
          parsed.host == '10.0.2.2';
      if (isLoopback && parsed.host != apiUri.host) {
        return parsed
            .replace(
              scheme: apiUri.scheme,
              host: apiUri.host,
              port: apiUri.hasPort ? apiUri.port : null,
            )
            .toString();
      }
      return input;
    }

    final normalized = input.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.startsWith('api/')) {
      return origin.replace(path: '/$normalized').toString();
    }

    final storagePath = normalized.replaceFirst(RegExp(r'^storage/'), '');
    return origin
        .replace(path: '/api/v1/images', queryParameters: {'path': storagePath})
        .toString();
  }

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers['Accept'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach JWT token if available
          final token = await _storageService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle token expiration (401 Unauthorized)
          if (e.response?.statusCode == 401) {
            final refreshToken = await _storageService.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Attempt token refresh
                final newTokens = await _refreshTokens(refreshToken);
                if (newTokens != null) {
                  // Save new tokens
                  await _storageService.saveTokens(
                    accessToken: newTokens['access_token']!,
                    refreshToken:
                        refreshToken, // backend doesn't return new refresh on refresh
                  );

                  // Retry the original request with new token
                  final options = e.requestOptions;
                  options.headers['Authorization'] =
                      'Bearer ${newTokens['access_token']}';

                  final response = await _dio.fetch(options);
                  return handler.resolve(response);
                }
              } catch (refreshError) {
                // Refresh failed, clear session and let app handle logout
                await _storageService.clearAll();
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;

  Future<String?> uploadImageBytes(List<int> bytes, String fileName) async {
    if (mockMode) return 'https://placehold.co/150x150/png';

    try {
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes, filename: fileName),
      });
      var response = await client.post('/upload', data: formData);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['path'];
      }
    } catch (e) {
      // Ignore or log
    }
    return null;
  }

  Future<Map<String, String>?> _refreshTokens(String refreshToken) async {
    if (mockMode) {
      return {
        'access_token':
            'mock_new_access_token_${DateTime.now().millisecondsSinceEpoch}',
      };
    }

    try {
      final response = await Dio().post(
        '$baseUrl/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return {
            'access_token': responseData['data']['access_token'] as String,
          };
        }
      }
    } catch (e) {
      // Refresh request failed
    }
    return null;
  }

  // --- MOCK API METHODS FOR FRONTEND INDEPENDENCE ---
  // If mockMode is true, these return simulated data immediately with a slight delay.

  Future<Response<T>> mockResponse<T>({
    required String path,
    required T data,
    int statusCode = 200,
  }) async {
    await Future.delayed(
      const Duration(milliseconds: 600),
    ); // Simulate network latency
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data,
      statusCode: statusCode,
    );
  }
}
