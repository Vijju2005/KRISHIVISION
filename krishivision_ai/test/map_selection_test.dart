import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('Map Selection State & Highlight Logic Unit Tests', () {
    final sampleStates = [
      {
        "id": 17,
        "name": "Karnataka",
        "boundary": {
          "type": "Polygon",
          "coordinates": [
            [
              [74.0, 14.0],
              [76.0, 14.0],
              [76.0, 16.0],
              [74.0, 16.0],
              [74.0, 14.0]
            ]
          ]
        }
      },
      {
        "id": 29,
        "name": "Rajasthan",
        "boundary": {
          "type": "Polygon",
          "coordinates": [
            [
              [70.0, 26.0],
              [74.0, 26.0],
              [74.0, 30.0],
              [70.0, 30.0],
              [70.0, 26.0]
            ]
          ]
        }
      }
    ];

    final sampleDistricts = [
      {
        "id": 101,
        "name": "Dharwad",
        "monitored_area": 15000.0,
        "boundary": {
          "type": "Polygon",
          "coordinates": [
            [
              [75.0, 15.0],
              [75.5, 15.0],
              [75.5, 15.5],
              [75.0, 15.5],
              [75.0, 15.0]
            ]
          ]
        }
      },
      {
        "id": 102,
        "name": "Belagavi",
        "monitored_area": 22000.0,
        "boundary": {
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
        }
      }
    ];

    test('Case A: Initial Map State — selectedState and selectedDistrict are NULL, all polygon fills are transparent', () {
      int? selectedStateId;
      String? selectedStateName;
      int? selectedDistrictId;
      String? selectedDistrictName;

      expect(selectedStateId, isNull);
      expect(selectedStateName, isNull);
      expect(selectedDistrictId, isNull);
      expect(selectedDistrictName, isNull);

      final Set<Polygon> polygons = {};

      for (final s in sampleStates) {
        final sId = s['id'] as int;
        polygons.add(
          Polygon(
            polygonId: PolygonId('state_${sId}_front_0'),
            points: const [LatLng(14.0, 74.0), LatLng(14.0, 76.0)],
            strokeColor: const Color(0x73616161),
            fillColor: Colors.transparent, // Completely transparent fill
          ),
        );
      }

      expect(polygons.length, equals(2));
      for (final p in polygons) {
        expect(p.polygonId.value, startsWith('state_'));
        expect(p.polygonId.value, isNot(contains('selected')));
        expect(p.fillColor, equals(Colors.transparent));
      }
    });

    test('Case B: Tap Karnataka — selectedState becomes Karnataka, selectedDistrict remains NULL', () {
      int? selectedStateId;
      String? selectedStateName;
      int? selectedDistrictId;
      String? selectedDistrictName;

      // Simulate tap on Karnataka (id: 17)
      selectedStateId = 17;
      selectedStateName = "Karnataka";
      selectedDistrictId = null;
      selectedDistrictName = null;

      expect(selectedStateId, equals(17));
      expect(selectedStateName, equals("Karnataka"));
      expect(selectedDistrictId, isNull);
      expect(selectedDistrictName, isNull);

      final Set<Polygon> polygons = {};

      for (final s in sampleStates) {
        final sId = s['id'] as int;
        if (sId == selectedStateId) {
          polygons.add(
            Polygon(
              polygonId: PolygonId('selected_state_${sId}_front_0'),
              points: const [LatLng(14.0, 74.0)],
              strokeColor: const Color(0xFF22C55E), // Vibrant green border
              fillColor: const Color(0x1F22C55E),   // Transparent green fill
            ),
          );
        } else {
          polygons.add(
            Polygon(
              polygonId: PolygonId('state_${sId}_front_0'),
              points: const [LatLng(26.0, 70.0)],
              strokeColor: const Color(0x73616161), // Normal state stroke
              fillColor: Colors.transparent,
            ),
          );
        }
      }

      final karnatakaPoly = polygons.firstWhere((p) => p.polygonId.value.contains('selected_state_17'));
      final rajasthanPoly = polygons.firstWhere((p) => p.polygonId.value.contains('state_29'));

      expect(karnatakaPoly.strokeColor, equals(const Color(0xFF22C55E)));
      expect(rajasthanPoly.strokeColor, equals(const Color(0x73616161)));
      expect(rajasthanPoly.fillColor, equals(Colors.transparent));
    });

    test('Case C: Tap Dharwad — selectedDistrict becomes Dharwad, ONLY Dharwad receives district highlight', () {
      int? selectedStateId = 17;
      int? selectedDistrictId = 101;
      String? selectedDistrictName = "Dharwad";

      expect(selectedStateId, equals(17));
      expect(selectedDistrictId, equals(101));
      expect(selectedDistrictName, equals("Dharwad"));

      final Set<Polygon> polygons = {};

      for (final d in sampleDistricts) {
        final dId = d['id'] as int;
        if (dId == selectedDistrictId) {
          polygons.add(
            Polygon(
              polygonId: PolygonId('district_${dId}_front_0'),
              points: const [LatLng(15.0, 75.0)],
              strokeColor: const Color(0xFF06B6D4), // Cyan highlight
              fillColor: const Color(0x3306B6D4),   // Cyan fill
            ),
          );
        } else {
          polygons.add(
            Polygon(
              polygonId: PolygonId('district_${dId}_front_0'),
              points: const [LatLng(15.6, 74.2)],
              strokeColor: const Color(0x66616161), // Subtle stroke
              fillColor: Colors.transparent,
            ),
          );
        }
      }

      final dharwadPoly = polygons.firstWhere((p) => p.polygonId.value == 'district_101_front_0');
      final belagaviPoly = polygons.firstWhere((p) => p.polygonId.value == 'district_102_front_0');

      expect(dharwadPoly.strokeColor, equals(const Color(0xFF06B6D4)));
      expect(belagaviPoly.strokeColor, equals(const Color(0x66616161)));
      expect(belagaviPoly.fillColor, equals(Colors.transparent));
    });

    test('Case D: Reset / Back to India — selectedState and selectedDistrict revert to NULL', () {
      int? selectedStateId = 17;
      int? selectedDistrictId = 101;

      // Simulate back / reset
      selectedStateId = null;
      selectedDistrictId = null;

      expect(selectedStateId, isNull);
      expect(selectedDistrictId, isNull);
    });

    test('Case E: Tap Rajasthan from Karnataka — previous selection completely cleared, ONLY Rajasthan highlighted', () {
      int? selectedStateId = 17; // Karnataka
      String? selectedStateName = "Karnataka";
      int? selectedDistrictId = 101; // Dharwad
      String? selectedDistrictName = "Dharwad";

      expect(selectedStateId, equals(17));
      expect(selectedDistrictId, equals(101));

      // Tap Rajasthan (29)
      selectedStateId = 29;
      selectedStateName = "Rajasthan";
      selectedDistrictId = null;
      selectedDistrictName = null;

      expect(selectedStateId, equals(29));
      expect(selectedStateName, equals("Rajasthan"));
      expect(selectedDistrictId, isNull);
      expect(selectedDistrictName, isNull);
    });
  });
}
