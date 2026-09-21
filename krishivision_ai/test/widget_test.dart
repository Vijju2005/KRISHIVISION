
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishivision_ai/main.dart';

void main() {
  // Disable font fetching at runtime during tests to prevent HTTP 400 errors
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('App renders splash screen and navigates to login when Get Started tapped', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        const ProviderScope(
          child: KrishiVisionApp(),
        ),
      );

      // Verify splash screen content is displayed
      expect(find.text('KrishiVision'), findsOneWidget);
      expect(find.text('Smart Satellite Crop Monitoring'), findsOneWidget);

      // Wait for initial loading/transition delay
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify Get Started button is visible
      final getStartedBtn = find.text('Get Started');
      expect(getStartedBtn, findsOneWidget);

      // Tap Get Started
      await tester.tap(getStartedBtn);
      await tester.pumpAndSettle();

      // Verify login screen content is displayed
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
    });
  });
}
