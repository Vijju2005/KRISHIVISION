import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapModel {
  final String crop;
  final String health;
  final double area;
  final LatLng center;
  final List<LatLng> polygon;

  MapModel({
    required this.crop,
    required this.health,
    required this.area,
    required this.center,
    required this.polygon,
  });

  factory MapModel.fromJson(Map<String, dynamic> json) {
    final crop = json['crop'] as String? ?? 'Maize';
    final health = json['health_status'] as String? ?? 'Healthy';
    final area = (json['area_acres'] as num? ?? 1.9).toDouble();

    final List<LatLng> polygonPoints = [];
    final boundary = json['boundary'];
    if (boundary != null && boundary is Map<String, dynamic>) {
      final coordinates = boundary['coordinates'];
      if (coordinates != null && coordinates is List && coordinates.isNotEmpty) {
        final ring = coordinates[0];
        if (ring is List) {
          for (final coord in ring) {
            if (coord is List && coord.length >= 2) {
              // GeoJSON is [longitude, latitude]
              final lng = (coord[0] as num).toDouble();
              final lat = (coord[1] as num).toDouble();
              polygonPoints.add(LatLng(lat, lng));
            }
          }
        }
      }
    }

    // Default Davanagere coordinates if empty
    if (polygonPoints.isEmpty) {
      polygonPoints.addAll([
        const LatLng(14.46011, 75.92120),
        const LatLng(14.46032, 75.92310),
        const LatLng(14.45911, 75.92351),
        const LatLng(14.45890, 75.92142),
      ]);
    }

    double latSum = 0.0;
    double lngSum = 0.0;
    for (final pt in polygonPoints) {
      latSum += pt.latitude;
      lngSum += pt.longitude;
    }
    final center = LatLng(latSum / polygonPoints.length, lngSum / polygonPoints.length);

    return MapModel(
      crop: crop,
      health: health,
      area: area,
      center: center,
      polygon: polygonPoints,
    );
  }
}
