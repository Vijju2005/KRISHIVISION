import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/startup_trace.dart';

class DashboardStats {
  final int totalAnalysis;
  final int healthyCrops;
  final int atRisk;
  final double totalArea;

  // New Redesign Properties
  final double monitoredAreaAcres;
  final double healthyAreaAcres;
  final double atRiskAreaAcres;
  final int totalCropsCount;
  final int upcomingHarvestCount;

  DashboardStats({
    this.totalAnalysis = 0,
    this.healthyCrops = 0,
    this.atRisk = 0,
    this.totalArea = 0.0,
    this.monitoredAreaAcres = 0.0,
    this.healthyAreaAcres = 0.0,
    this.atRiskAreaAcres = 0.0,
    this.totalCropsCount = 0,
    this.upcomingHarvestCount = 0,
  });
}

class WeatherData {
  final double temp;
  final double humidity;
  final double rainProb;
  final double windSpeed;
  final String condition;

  WeatherData({
    this.temp = 28.5,
    this.humidity = 70.0,
    this.rainProb = 20.0,
    this.windSpeed = 12.0,
    this.condition = 'Clear Sky',
  });
}

class DashboardState {
  final bool isLoading;
  final DashboardStats stats;
  final WeatherData weather;
  final List<dynamic> recentAnalyses;
  final List<dynamic> notifications;
  final List<dynamic> alerts;
  final List<String> monitoredCrops;
  final String? error;

  DashboardState({
    this.isLoading = true,
    required this.stats,
    required this.weather,
    this.recentAnalyses = const [],
    this.notifications = const [],
    this.alerts = const [],
    this.monitoredCrops = const [],
    this.error,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardStats? stats,
    WeatherData? weather,
    List<dynamic>? recentAnalyses,
    List<dynamic>? notifications,
    List<dynamic>? alerts,
    List<String>? monitoredCrops,
    String? error,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      weather: weather ?? this.weather,
      recentAnalyses: recentAnalyses ?? this.recentAnalyses,
      notifications: notifications ?? this.notifications,
      alerts: alerts ?? this.alerts,
      monitoredCrops: monitoredCrops ?? this.monitoredCrops,
      error: error ?? this.error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final _api = ApiClient();
  bool _isFetching = false;

  DashboardNotifier()
      : super(
          DashboardState(
            stats: DashboardStats(),
            weather: WeatherData(),
          ),
        ) {
    loadDashboard();
  }

  Future<void> loadDashboard({bool forceRefresh = false}) async {
    if (_isFetching && !forceRefresh) return;
    _isFetching = true;

    // Keep existing data visible while refreshing in background if data already exists
    state = state.copyWith(isLoading: state.stats.monitoredAreaAcres == 0.0 && state.recentAnalyses.isEmpty, error: null);

    try {
      final responses = await Future.wait([
        _api.get('/analysis/history').catchError((_) => null),
        _api.get('/weather/current', queryParameters: {'lat': 14.4650, 'lng': 75.9200}).catchError((_) => null),
        _api.get('/dashboard/summary').catchError((_) => null),
        _api.get('/notifications').catchError((_) => null),
        _api.get('/dashboard/alerts').catchError((_) => null),
      ]);

      final historyResp = responses[0];
      final weatherResp = responses[1];
      final summaryResp = responses[2];
      final notifyResp = responses[3];
      final alertsResp = responses[4];

      // 1. Process History
      final List<dynamic> history = (historyResp != null && historyResp.statusCode == 200 && historyResp.data is List)
          ? historyResp.data
          : state.recentAnalyses;

      int total = history.length;
      int healthy = 0;
      int risk = 0;
      double area = 0.0;

      for (var item in history) {
        final status = item['health_status'] ?? '';
        if (status == 'Healthy') {
          healthy++;
        } else if (status == 'At Risk' || status == 'Unhealthy') {
          risk++;
        }
        area += (item['area_acres'] as num? ?? 0.0).toDouble();
      }

      // 2. Process Weather
      WeatherData weather = state.weather;
      if (weatherResp != null && weatherResp.statusCode == 200 && weatherResp.data is Map) {
        final wd = weatherResp.data;
        weather = WeatherData(
          temp: (wd['temp'] as num? ?? 28.5).toDouble(),
          humidity: (wd['humidity'] as num? ?? 70.0).toDouble(),
          rainProb: (wd['rain_probability'] as num? ?? 20.0).toDouble(),
          windSpeed: (wd['wind_speed'] as num? ?? 12.0).toDouble(),
          condition: wd['condition'] ?? 'Clear',
        );
      }

      // 3. Process Summary
      double monitoredArea = state.stats.monitoredAreaAcres;
      double healthyArea = state.stats.healthyAreaAcres;
      double atRiskArea = state.stats.atRiskAreaAcres;
      int totalCropsCount = state.stats.totalCropsCount;
      int upcomingHarvestCount = state.stats.upcomingHarvestCount;

      if (summaryResp != null && summaryResp.statusCode == 200 && summaryResp.data is Map) {
        final data = summaryResp.data;
        monitoredArea = (data['total_monitored_area'] as num? ?? 0.0).toDouble();
        healthyArea = (data['healthy_area'] as num? ?? 0.0).toDouble();
        atRiskArea = (data['at_risk_area'] as num? ?? 0.0).toDouble();
        totalCropsCount = (data['total_crops'] as num? ?? 0).toInt();
        upcomingHarvestCount = (data['upcoming_harvest'] as num? ?? 0).toInt();
      }

      final List<String> monitoredCrops = history
          .map((item) => (item['crop'] as String? ?? '').trim())
          .where((crop) => crop.isNotEmpty)
          .toSet()
          .toList();

      // 4. Process Notifications & Alerts
      List<dynamic> notifications = (notifyResp != null && notifyResp.statusCode == 200 && notifyResp.data is List)
          ? notifyResp.data
          : state.notifications;

      List<dynamic> alerts = (alertsResp != null && alertsResp.statusCode == 200 && alertsResp.data is List)
          ? alertsResp.data
          : state.alerts;

      state = DashboardState(
        isLoading: false,
        stats: DashboardStats(
          totalAnalysis: total,
          healthyCrops: healthy,
          atRisk: risk,
          totalArea: double.parse(area.toStringAsFixed(1)),
          monitoredAreaAcres: monitoredArea,
          healthyAreaAcres: healthyArea,
          atRiskAreaAcres: atRiskArea,
          totalCropsCount: totalCropsCount,
          upcomingHarvestCount: upcomingHarvestCount,
        ),
        weather: weather,
        recentAnalyses: history.take(5).toList(),
        monitoredCrops: monitoredCrops,
        notifications: notifications,
        alerts: alerts,
      );

      StartupTrace.markT6();
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard data.',
      );
      StartupTrace.markT6();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> markNotificationsAsRead() async {
    try {
      await _api.post('/notifications/read');
      loadDashboard(forceRefresh: true);
    } catch (_) {}
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
