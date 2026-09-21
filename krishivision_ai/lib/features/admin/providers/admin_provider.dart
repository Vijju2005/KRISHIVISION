import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

class AdminDashboardStats {
  final int totalUsers;
  final int totalFarms;
  final int totalAnalyses;
  final List<dynamic> cropDistribution; // e.g. [{'crop': 'Rice', 'count': 5}, ...]

  AdminDashboardStats({
    this.totalUsers = 0,
    this.totalFarms = 0,
    this.totalAnalyses = 0,
    this.cropDistribution = const [],
  });
}

class AdminState {
  final bool isLoading;
  final AdminDashboardStats stats;
  final List<dynamic> usersList;
  final List<dynamic> recentAnalyses;
  final String? error;

  AdminState({
    this.isLoading = true,
    required this.stats,
    this.usersList = const [],
    this.recentAnalyses = const [],
    this.error,
  });

  AdminState copyWith({
    bool? isLoading,
    AdminDashboardStats? stats,
    List<dynamic>? usersList,
    List<dynamic>? recentAnalyses,
    String? error,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      usersList: usersList ?? this.usersList,
      recentAnalyses: recentAnalyses ?? this.recentAnalyses,
      error: error ?? this.error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final _api = ApiClient();

  AdminNotifier() : super(AdminState(stats: AdminDashboardStats())) {
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final statsResponse = await _api.get('/admin/stats');
      final usersResponse = await _api.get('/admin/users');
      final analysesResponse = await _api.get('/admin/analyses');

      final statsData = statsResponse.data;
      final List<dynamic> users = usersResponse.data;
      final List<dynamic> analyses = analysesResponse.data;

      // Group crop counts locally
      final Map<String, int> cropCounts = {};
      for (var item in analyses) {
        final crop = item['crop'] ?? 'Unknown';
        cropCounts[crop] = (cropCounts[crop] ?? 0) + 1;
      }
      final cropDist = cropCounts.entries.map((e) => {'crop': e.key, 'count': e.value}).toList();

      state = AdminState(
        isLoading: false,
        stats: AdminDashboardStats(
          totalUsers: statsData['total_users'] ?? users.length,
          totalFarms: statsData['total_farms'] ?? 2,
          totalAnalyses: statsData['total_analyses'] ?? analyses.length,
          cropDistribution: cropDist,
        ),
        usersList: users,
        recentAnalyses: analyses,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to retrieve administrative data. Ensure admin privileges.',
      );
    }
  }

  Future<void> updateUserRole(int userId, String newRole) async {
    try {
      await _api.post('/admin/users/$userId/role', data: {'role': newRole});
      loadAdminData();
    } catch (_) {}
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});
