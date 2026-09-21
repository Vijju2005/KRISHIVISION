import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

class HistoryState {
  final bool isLoading;
  final List<dynamic> rawItems;
  final List<dynamic> filteredItems;
  final List<String> availableCrops;
  final String searchQuery;
  final String filterCrop; // 'All', 'Rice', etc.
  final String filterHealth; // 'All', 'Healthy', 'At Risk'
  final String sortBy; // 'date_desc', 'date_asc', 'area_desc'
  final String? error;

  HistoryState({
    this.isLoading = true,
    this.rawItems = const [],
    this.filteredItems = const [],
    this.availableCrops = const ['All'],
    this.searchQuery = '',
    this.filterCrop = 'All',
    this.filterHealth = 'All',
    this.sortBy = 'date_desc',
    this.error,
  });

  HistoryState copyWith({
    bool? isLoading,
    List<dynamic>? rawItems,
    List<dynamic>? filteredItems,
    List<String>? availableCrops,
    String? searchQuery,
    String? filterCrop,
    String? filterHealth,
    String? sortBy,
    String? error,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      rawItems: rawItems ?? this.rawItems,
      filteredItems: filteredItems ?? this.filteredItems,
      availableCrops: availableCrops ?? this.availableCrops,
      searchQuery: searchQuery ?? this.searchQuery,
      filterCrop: filterCrop ?? this.filterCrop,
      filterHealth: filterHealth ?? this.filterHealth,
      sortBy: sortBy ?? this.sortBy,
      error: error ?? this.error,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final _api = ApiClient();

  HistoryNotifier() : super(HistoryState()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/analysis/history');
      final List<dynamic> items = response.data;
      state = state.copyWith(
        isLoading: false,
        rawItems: items,
        filteredItems: _applyFilters(items, state.searchQuery, state.filterCrop, state.filterHealth, state.sortBy),
      );
      await loadAvailableCrops();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load analysis history.');
    }
  }

  Future<void> loadAvailableCrops() async {
    final defaultCrops = [
      'Rice', 'Wheat', 'Maize', 'Sugarcane', 'Cotton', 'Groundnut', 
      'Soybean', 'Pulses', 'Coffee', 'Tea', 'Coconut', 'Arecanut', 
      'Black Pepper', 'Cardamom', 'Banana', 'Turmeric', 'Ginger', 'Mustard'
    ];

    try {
      final response = await _api.get('/crops/all-names');
      final List<dynamic> list = response.data;
      
      final Set<String> uniqueCrops = {'All'};
      for (final crop in defaultCrops) {
        uniqueCrops.add(crop);
      }
      
      for (final dynamic item in list) {
        if (item != null) {
          final c = item.toString().trim();
          if (c.isNotEmpty) {
            final exists = uniqueCrops.any((x) => x.toLowerCase() == c.toLowerCase());
            if (!exists) {
              uniqueCrops.add(c);
            }
          }
        }
      }
      
      for (final dynamic item in state.rawItems) {
        final c = (item['crop'] ?? item['crop_name'] ?? '').toString().trim();
        if (c.isNotEmpty) {
          final exists = uniqueCrops.any((x) => x.toLowerCase() == c.toLowerCase());
          if (!exists) {
            uniqueCrops.add(c);
          }
        }
      }
      
      final sortedCrops = ['All', ...uniqueCrops.where((x) => x != 'All').toList()..sort()];
      
      print('[DEBUG] API response crop count: ${list.length}');
      print('[DEBUG] Final dropdown crop count: ${sortedCrops.length}');
      
      state = state.copyWith(availableCrops: sortedCrops);
    } catch (e) {
      final Set<String> uniqueCrops = {'All'};
      for (final crop in defaultCrops) {
        uniqueCrops.add(crop);
      }
      for (final dynamic item in state.rawItems) {
        final c = (item['crop'] ?? item['crop_name'] ?? '').toString().trim();
        if (c.isNotEmpty) {
          final exists = uniqueCrops.any((x) => x.toLowerCase() == c.toLowerCase());
          if (!exists) {
            uniqueCrops.add(c);
          }
        }
      }
      final sortedCrops = ['All', ...uniqueCrops.where((x) => x != 'All').toList()..sort()];
      print('[DEBUG] API failed: $e. Using local fallback. Final dropdown crop count: ${sortedCrops.length}');
      state = state.copyWith(availableCrops: sortedCrops);
    }
  }

  Future<bool> deleteAnalysis(int jobId) async {
    try {
      await _api.delete('/analysis/$jobId');
      await loadHistory();
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredItems: _applyFilters(state.rawItems, query, state.filterCrop, state.filterHealth, state.sortBy),
    );
  }

  void updateFilters({String? crop, String? health, String? sort}) {
    final nextCrop = crop ?? state.filterCrop;
    final nextHealth = health ?? state.filterHealth;
    final nextSort = sort ?? state.sortBy;

    final filtered = _applyFilters(state.rawItems, state.searchQuery, nextCrop, nextHealth, nextSort);

    print('[DEBUG] selected crop: $nextCrop');
    print('[DEBUG] number of reports after filtering: ${filtered.length}');

    state = state.copyWith(
      filterCrop: nextCrop,
      filterHealth: nextHealth,
      sortBy: nextSort,
      filteredItems: filtered,
    );
  }

  List<dynamic> _applyFilters(
    List<dynamic> items,
    String query,
    String crop,
    String health,
    String sort,
  ) {
    List<dynamic> list = List.from(items);

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((item) {
        final cropName = (item['crop'] ?? '').toString().toLowerCase();
        final district = (item['district'] ?? '').toString().toLowerCase();
        return cropName.contains(q) || district.contains(q);
      }).toList();
    }

    if (crop != 'All') {
      list = list.where((item) => (item['crop'] as String?)?.toLowerCase() == crop.toLowerCase()).toList();
    }

    if (health != 'All') {
      list = list.where((item) => item['health_status'] == health).toList();
    }

    if (sort == 'date_desc') {
      list.sort((a, b) => b['created_at'].toString().compareTo(a['created_at'].toString()));
    } else if (sort == 'date_asc') {
      list.sort((a, b) => a['created_at'].toString().compareTo(b['created_at'].toString()));
    } else if (sort == 'area_desc') {
      list.sort((a, b) {
        final areaA = (a['area_acres'] as num? ?? 0).toDouble();
        final areaB = (b['area_acres'] as num? ?? 0).toDouble();
        return areaB.compareTo(areaA);
      });
    }

    return list;
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
