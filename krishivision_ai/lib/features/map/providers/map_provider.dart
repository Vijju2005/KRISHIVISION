import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/map_repository.dart';
import 'map_state.dart';

class MapNotifier extends StateNotifier<MapState> {
  final MapRepository _repository = MapRepository();

  MapNotifier() : super(MapState()) {
    loadMapData();
  }

  Future<void> loadMapData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final mapData = await _repository.fetchLatestFarmMap();
      state = state.copyWith(isLoading: false, mapData: mapData);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }

  void toggleMapType() {
    state = state.copyWith(isSatellite: !state.isSatellite);
  }
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});
