import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../models/map_model.dart';

class MapRepository {
  final ApiClient _api = ApiClient();

  Future<MapModel> fetchLatestFarmMap() async {
    try {
      // 1. Fetch analysis history to locate the latest processed job ID
      final historyResponse = await _api.get('/analysis/history');
      if (historyResponse.statusCode == 200) {
        final List<dynamic> list = historyResponse.data;
        if (list.isNotEmpty) {
          // Check for id or job_id
          final latestJobId = list.first['job_id'] ?? list.first['id'];
          
          // 2. Fetch the field boundary coordinates for the found job ID
          final boundaryResponse = await _api.get('/fields/$latestJobId/boundary');
          if (boundaryResponse.statusCode == 200) {
            return MapModel.fromJson(boundaryResponse.data);
          }
        }
      }
      throw Exception("No farm analyses recorded yet. Please perform a crop analysis upload first.");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.sendTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception("Connection timed out. Please check your internet connectivity.");
      } else if (e.error is SocketException) {
        throw Exception("No internet connection detected. Please verify your Wi-Fi or cellular network.");
      } else if (e.response != null) {
        throw Exception("Server error [${e.response?.statusCode}]: ${e.response?.data['detail'] ?? 'Failed to retrieve data'}");
      }
      throw Exception("Network communication failed: ${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
