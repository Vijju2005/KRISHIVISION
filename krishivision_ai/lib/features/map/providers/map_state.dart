import '../models/map_model.dart';

class MapState {
  final bool isLoading;
  final String? error;
  final MapModel? mapData;
  final bool isSatellite;

  MapState({
    this.isLoading = false,
    this.error,
    this.mapData,
    this.isSatellite = true, // Satellite mode by default
  });

  MapState copyWith({
    bool? isLoading,
    String? error,
    MapModel? mapData,
    bool? isSatellite,
  }) {
    return MapState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can set to null explicitly
      mapData: mapData ?? this.mapData,
      isSatellite: isSatellite ?? this.isSatellite,
    );
  }
}
