import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';
import '../config/app_config.dart';

class ApiClient {
  static String? discoveredBaseUrl;
  static DateTime? _lastHealthCheckTime;
  static VoidCallback? onTokenExpired;
  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  ApiClient() {
    String baseUrl = discoveredBaseUrl ?? AppConfig.backendBaseUrl;

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Request & auth interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (discoveredBaseUrl == null) {
              discoveredBaseUrl = await resolveDefaultBaseUrl(forceRefresh: false);
            }
            options.baseUrl = discoveredBaseUrl!;
          } catch (e) {
            debugPrint('Failed to resolve base URL: $e');
            options.baseUrl = AppConfig.backendBaseUrl;
            discoveredBaseUrl = options.baseUrl;
          }

          // Temporary diagnostic log showing ONLY API BASE URL
          debugPrint('API BASE URL: ${options.baseUrl}');

          // Log final request URL before every API request
          debugPrint('API Request: [${options.method}] ${options.baseUrl}${options.path}');
          
          final token = await _storage.read('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('Token present: YES');
            debugPrint('Authorization header: Bearer ***REDACTED***');
          } else {
            debugPrint('Token present: NO');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('API Response: [${response.requestOptions.method}] ${response.requestOptions.baseUrl}${response.requestOptions.path} -> Status: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            final errBody = e.response?.data.toString() ?? "";
            if (errBody.contains("Invalid or expired token") ||
                errBody.contains("Missing or invalid Authorization header") ||
                errBody.contains("User not found") ||
                errBody.contains("Unauthorized")) {
              debugPrint('Token expired: YES');
              debugPrint('JWT token is invalid or expired. Triggering logout.');
              _storage.delete('jwt_token');
              discoveredBaseUrl = null;
              _lastHealthCheckTime = null;
              if (onTokenExpired != null) {
                onTokenExpired!();
              }
            }
          }

          // Clear cached dynamic base URL on network/connection failure
          if (e.type == DioExceptionType.connectionTimeout || 
              e.type == DioExceptionType.sendTimeout || 
              e.type == DioExceptionType.receiveTimeout || 
              e.type == DioExceptionType.connectionError ||
              e.error is SocketException) {
            debugPrint('Connection error detected (${e.type}: ${e.error}). Invalidate cached backend URL.');
            discoveredBaseUrl = null;
            _lastHealthCheckTime = null;
            SharedPreferences.getInstance().then((prefs) {
              if (prefs.containsKey('discovered_api_base_url')) {
                debugPrint('Clearing unreachable auto-discovered API URL from SharedPreferences.');
                prefs.remove('discovered_api_base_url');
              }
            });
          }

          String errorMessage = 'Unknown API error occurred';
          
          if (e.type == DioExceptionType.connectionTimeout || 
              e.type == DioExceptionType.sendTimeout || 
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.error is SocketException ||
              e.message?.contains('SocketException') == true ||
              e.message?.contains('Connection refused') == true ||
              e.message?.contains('Network is unreachable') == true ||
              e.message?.contains('unreachable') == true) {
            errorMessage = 'Backend unavailable: Unable to connect to the KrishiVision AI server.';
          } else if (e.response != null) {
            final responseData = e.response?.data;
            dynamic detailMsg;
            if (responseData is Map) {
              detailMsg = responseData['detail'] ?? responseData['message'];
            }

            if (detailMsg != null && detailMsg.toString().isNotEmpty) {
              errorMessage = detailMsg.toString();
            } else {
              final status = e.response?.statusCode;
              if (status == 404) {
                errorMessage = 'No crop data available for this district';
              } else if (status == 400) {
                errorMessage = 'Bad request. Please check your query inputs.';
              } else if (status == 401) {
                errorMessage = 'Session expired. Please login again.';
              } else if (status == 403) {
                errorMessage = 'Access forbidden. Verification failed.';
              } else if (status == 500) {
                errorMessage = 'Server error. Please try again.';
              } else if (status == 503) {
                errorMessage = 'Crop data temporarily unavailable';
              } else {
                errorMessage = 'Crop data temporarily unavailable';
              }
            }
          } else {
            errorMessage = 'Backend unavailable: Unable to connect to the KrishiVision AI server.';
          }

          debugPrint('Resolved API Error: $errorMessage');
          
          final customException = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
            message: errorMessage,
          );
          
          return handler.next(customException);
        },
      ),
    );
  }

  Future<bool> _isBaseUrlHealthy(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse('$url/health'));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        return json['status'] == 'healthy' || json['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  Future<String> resolveDefaultBaseUrl({bool forceRefresh = false}) async {
    if (kIsWeb) return 'http://localhost:8000';

    final prefs = await SharedPreferences.getInstance();
    final savedApiUrl = prefs.getString('api_base_url');
    final savedDiscoveredUrl = prefs.getString('discovered_api_base_url');

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final url = savedApiUrl ?? savedDiscoveredUrl ?? AppConfig.backendBaseUrl;
      discoveredBaseUrl = url;
      return url;
    }

    if (!forceRefresh && discoveredBaseUrl != null) {
      return discoveredBaseUrl!;
    }

    bool isProdUrl(String url) {
      return url.isNotEmpty &&
          url.startsWith('https://') &&
          !url.contains('YOUR-PRODUCTION-BACKEND-DOMAIN') &&
          !url.contains('YOUR-ACTUAL-PRODUCTION-BACKEND-DOMAIN');
    }

    final String prodUrl = AppConfig.backendBaseUrl;

    // 1. Priority 1: Explicit production BACKEND_URL from compile-time / AppConfig
    if (isProdUrl(prodUrl)) {
      discoveredBaseUrl = prodUrl;
      if (savedDiscoveredUrl != null) {
        await prefs.remove('discovered_api_base_url');
      }
      return prodUrl;
    }

    // 2. Priority 2: Valid saved backend URL (manually entered by user in settings)
    if (savedApiUrl != null && savedApiUrl.trim().isNotEmpty) {
      final url = savedApiUrl.trim();
      final ok = await _isBaseUrlHealthy(url);
      if (ok) {
        discoveredBaseUrl = url;
        return url;
      }
      debugPrint('Saved api_base_url ($url) is unreachable. Removing from SharedPreferences.');
      await prefs.remove('api_base_url');
    }

    // 3. Priority 3: Development LAN URL only during development
    if (!kReleaseMode) {
      if (savedDiscoveredUrl != null && savedDiscoveredUrl.trim().isNotEmpty) {
        final url = savedDiscoveredUrl.trim();
        final ok = await _isBaseUrlHealthy(url);
        if (ok) {
          discoveredBaseUrl = url;
          return url;
        }
        debugPrint('Stale discovered_api_base_url ($url) cleared.');
        await prefs.remove('discovered_api_base_url');
      }

      final localUrls = [
        'http://127.0.0.1:8000',
        'http://10.0.2.2:8000',
        'http://10.0.3.2:8000',
      ];
      for (final url in localUrls) {
        final ok = await _isBaseUrlHealthy(url);
        if (ok) {
          discoveredBaseUrl = url;
          return url;
        }
      }

      debugPrint('Scanning LAN subnets for backend server...');
      final discoveredIp = await _scanLocalSubnetForBackend();
      if (discoveredIp != null) {
        discoveredBaseUrl = discoveredIp;
        await prefs.setString('discovered_api_base_url', discoveredIp);
        return discoveredIp;
      }
    }

    // Fallback: If nothing works, always use the configured production URL
    discoveredBaseUrl = prodUrl;
    return prodUrl;
  }

  Future<String?> _scanLocalSubnetForBackend() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      final List<String> subnetPrefixes = [];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.') || _isPrivateIPv4(ip)) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
              if (!subnetPrefixes.contains(prefix)) {
                subnetPrefixes.add(prefix);
              }
            }
          }
        }
      }

      // Fallback: add subnet of default compile-time URL if parsing is successful
      try {
        final uri = Uri.parse(AppConfig.backendBaseUrl);
        final host = uri.host;
        final parts = host.split('.');
        if (parts.length == 4) {
          final defaultPrefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
          if (!subnetPrefixes.contains(defaultPrefix)) {
            subnetPrefixes.add(defaultPrefix);
          }
        }
      } catch (_) {}

      if (subnetPrefixes.isEmpty) {
        subnetPrefixes.addAll(['192.168.1.', '192.168.0.', '192.168.9.']);
      }

      for (final prefix in subnetPrefixes) {
        // Probe IPs in concurrent batches of 30
        for (int chunkStart = 1; chunkStart < 255; chunkStart += 30) {
          final List<Future<String?>> scanFutures = [];
          for (int i = chunkStart; i < chunkStart + 30 && i < 255; i++) {
            final testIp = '$prefix$i';
            scanFutures.add(_probeIp(testIp));
          }
          final results = await Future.wait(scanFutures);
          for (final res in results) {
            if (res != null) {
              return res; // Immediate return on discovery
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error list/scanning subnet interfaces: $e');
    }
    return null;
  }

  bool _isPrivateIPv4(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return false;
      if (parts[0] == 10) return true;
      if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
      if (parts[0] == 192 && parts[1] == 168) return true;
    } catch (_) {}
    return false;
  }

  Future<String?> _probeIp(String ip) async {
    const int targetPort = 8000;
    final url = 'http://$ip:$targetPort';
    try {
      final socket = await Socket.connect(
        ip,
        targetPort,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 1);
      final req = await client.getUrl(Uri.parse('$url/health'));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json['status'] == 'healthy' || json['status'] == 'ok') {
          return url;
        }
      }
    } catch (_) {}
    return null;
  }

  static final Map<String, Future<Response>> _ongoingGetRequests = {};

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final String key = '$path?${queryParameters?.toString() ?? ""}';
    if (_ongoingGetRequests.containsKey(key)) {
      debugPrint('Deduplication: Reusing ongoing GET request for $key');
      return _ongoingGetRequests[key]!;
    }

    Future<Response> executeGetWithRetry() async {
      const int maxAttempts = 2;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          return await dio.get(path, queryParameters: queryParameters);
        } on DioException catch (e) {
          final isTimeout = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError;
          if (isTimeout && attempt < maxAttempts) {
            debugPrint('GET request timed out ($key, attempt $attempt/$maxAttempts). Retrying in 1s...');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          rethrow;
        }
      }
      return dio.get(path, queryParameters: queryParameters);
    }

    final Future<Response> future = executeGetWithRetry();
    _ongoingGetRequests[key] = future;

    try {
      final Response response = await future;
      return response;
    } finally {
      _ongoingGetRequests.remove(key);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    return dio.post(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return dio.delete(path, data: data);
  }

  Future<Response> uploadFile(String path, String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return dio.post(
      path,
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }
}
