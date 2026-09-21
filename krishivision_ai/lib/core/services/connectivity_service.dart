import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../config/app_config.dart';

enum ConnectionStatus {
  wifi,
  mobile,
  offline,
  serverUnavailable,
}

class ConnectivityService {
  Future<ConnectionStatus> checkStatus({bool checkBackend = false}) async {
    try {
      final interfaces = await NetworkInterface.list();
      if (interfaces.isEmpty) {
        return ConnectionStatus.offline;
      }

      bool hasWifi = false;
      bool hasMobile = false;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan')) {
          hasWifi = true;
        } else if (name.contains('rmnet') ||
            name.contains('ccmni') ||
            name.contains('lte') ||
            name.contains('p2p') ||
            name.contains('dun')) {
          hasMobile = true;
        }
      }

      if (checkBackend) {
        final isBackendAvailable = await checkBackendHealth();
        if (!isBackendAvailable) {
          return ConnectionStatus.serverUnavailable;
        }
      }

      if (hasWifi) {
        return ConnectionStatus.wifi;
      } else if (hasMobile) {
        return ConnectionStatus.mobile;
      }

      return ConnectionStatus.wifi; // Default fallback if any interface exists
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return ConnectionStatus.offline;
    }
  }

  Future<bool> checkBackendHealth() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. First, attempt connection using the active/configured base URL in ApiClient
    try {
      final api = ApiClient();
      debugPrint('[API] Backend URL: ${api.dio.options.baseUrl}');
      debugPrint('[API] Health check started');
      
      final response = await api.dio.get('/health').timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && (data['status'] == 'ok' || data['status'] == 'healthy')) {
          debugPrint('[API] Health check successful');
          final currentUrl = api.dio.options.baseUrl;
          if (currentUrl != AppConfig.backendBaseUrl) {
            await prefs.setString('discovered_api_base_url', currentUrl);
          }
          return true;
        }
      }
      debugPrint('[API] Connection failed');
    } catch (e) {
      debugPrint('[API] Connection failed: $e');
    }

    // 2. If initial check failed, the cached IP is stale. Clear it!
    debugPrint('[API] Clearing stale backend URL');
    ApiClient.discoveredBaseUrl = null;
    await prefs.remove('discovered_api_base_url');
    
    // Reset ApiClient base options to default fallback config before resolving
    final api = ApiClient();
    api.dio.options.baseUrl = AppConfig.backendBaseUrl;

    try {
      // 3. Run subnet/emulator auto-discovery
      debugPrint('[API] Starting backend auto-discovery');
      final discoveredUrl = await api.resolveDefaultBaseUrl();
      debugPrint('[API] Backend URL discovered: $discoveredUrl');
      debugPrint('[API] Health check started for discovered URL');
      
      final tempDio = Dio(
        BaseOptions(
          baseUrl: discoveredUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      final response = await tempDio.get('/health');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && (data['status'] == 'ok' || data['status'] == 'healthy')) {
          debugPrint('[API] Health check successful');
          ApiClient.discoveredBaseUrl = discoveredUrl;
          api.dio.options.baseUrl = discoveredUrl;
          if (discoveredUrl != AppConfig.backendBaseUrl) {
            await prefs.setString('discovered_api_base_url', discoveredUrl);
          }
          return true;
        }
      }
      debugPrint('[API] Connection failed for discovered URL');
    } catch (e) {
      debugPrint('[API] Connection failed during auto-discovery: $e');
    }

    return false;
  }
}
