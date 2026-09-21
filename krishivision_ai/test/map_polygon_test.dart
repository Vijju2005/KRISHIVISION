import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('Map Polygon & GeoJSON Conversion Tests', () {
    test('GeoJSON Polygon [lng, lat] correctly converts to Google Maps LatLng(lat, lng)', () {
      final geoJson = {
        "type": "Polygon",
        "coordinates": [
          [
            [74.2, 15.6],
            [74.8, 15.6],
            [74.8, 16.2],
            [74.2, 16.2],
            [74.2, 15.6]
          ]
        ]
      };

      final coords = geoJson['coordinates'] as List;
      final ring = coords[0] as List;
      final List<LatLng> points = [];

      for (final pt in ring) {
        final lng = (pt[0] as num).toDouble();
        final lat = (pt[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }

      expect(points.length, equals(5));
      expect(points[0].latitude, equals(15.6));
      expect(points[0].longitude, equals(74.2));
      expect(points[2].latitude, equals(16.2));
      expect(points[2].longitude, equals(74.8));
    });

    test('GeoJSON MultiPolygon correctly converts outer rings into LatLng point lists', () {
      final geoJson = {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [74.0, 14.0],
              [75.0, 14.0],
              [75.0, 15.0],
              [74.0, 15.0],
              [74.0, 14.0]
            ]
          ],
          [
            [
              [76.0, 16.0],
              [77.0, 16.0],
              [77.0, 17.0],
              [76.0, 17.0],
              [76.0, 16.0]
            ]
          ]
        ]
      };

      final coords = geoJson['coordinates'] as List;
      final List<List<LatLng>> polygons = [];

      for (final poly in coords) {
        final ring = (poly as List)[0] as List;
        final List<LatLng> points = [];
        for (final pt in ring) {
          final lng = (pt[0] as num).toDouble();
          final lat = (pt[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }
        polygons.add(points);
      }

      expect(polygons.length, equals(2));
      expect(polygons[0][0].latitude, equals(14.0));
      expect(polygons[0][0].longitude, equals(74.0));
      expect(polygons[1][0].latitude, equals(16.0));
      expect(polygons[1][0].longitude, equals(76.0));
    });

    test('Centroid calculation for MultiPolygon finds accurate center', () {
      final polyList = [
        [
          const LatLng(14.0, 74.0),
          const LatLng(14.0, 76.0),
          const LatLng(16.0, 76.0),
          const LatLng(16.0, 74.0),
          const LatLng(14.0, 74.0)
        ]
      ];

      double minLat = polyList[0][0].latitude;
      double maxLat = polyList[0][0].latitude;
      double minLng = polyList[0][0].longitude;
      double maxLng = polyList[0][0].longitude;

      for (final p in polyList[0]) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final centroid = LatLng((minLat + maxLat) / 2.0, (minLng + maxLng) / 2.0);

      expect(centroid.latitude, equals(15.0));
      expect(centroid.longitude, equals(75.0));
    });
  });
}
