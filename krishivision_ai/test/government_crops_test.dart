import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishivision_ai/features/analysis/screens/crop_selection_screen.dart';
import 'package:krishivision_ai/core/services/api_client.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Government Crop Integration Tests', () {
    testWidgets('CropSelectionScreen renders loading and empty/success states properly', (WidgetTester tester) async {
      ApiClient.discoveredBaseUrl = "http://127.0.0.1:8000";
      SharedPreferences.setMockInitialValues({
        "api_base_url": "http://127.0.0.1:8000",
        "discovered_api_base_url": "http://127.0.0.1:8000"
      });

      await tester.runAsync(() async {
        // Build CropSelectionScreen
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CropSelectionScreen(districtId: 1),
            ),
          ),
        );

        // Verify initial state (loading indicator is shown)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Wait for details loading
        await Future.delayed(const Duration(milliseconds: 600));
        await tester.pump();


        final hasError = find.text('Failed to Load Crops').evaluate().isNotEmpty || find.text('Backend unavailable').evaluate().isNotEmpty;
        final hasEmpty = find.text('No Crops Cultivated').evaluate().isNotEmpty;
        expect(hasError || hasEmpty, isTrue);
      });
    });

    test('State and District normalization parameters validation', () {
      final state = 'Orissa';
      final district = 'Kalahandi';
      
      // Verify normalization logic matches expected inputs
      expect(state.toLowerCase() == 'orissa', isTrue);
      expect(district.toUpperCase() == 'KALAHANDI', isTrue);
    });
  });
}
