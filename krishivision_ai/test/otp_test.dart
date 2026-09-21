import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishivision_ai/features/auth/screens/otp_verification_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('OtpVerificationScreen renders phone number and OTP fields', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(phoneNumber: '+919876543210'),
          ),
        ),
      );

      // Wait a short moment for async SecureStorage _initSession to complete and set isLoading to false
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      // Verify OTP instruction texts are rendered
      expect(find.text('Verify your mobile number'), findsOneWidget);
      expect(find.textContaining('3210'), findsOneWidget);
      
      // Verify 6 OTP boxes are rendered (each box is a TextFormField)
      expect(find.byType(TextFormField), findsNWidgets(6));
      
      // Verify VERIFY OTP button exists
      expect(find.text('VERIFY OTP'), findsOneWidget);
      
      // Verify countdown timer text or resend option is present
      expect(find.textContaining('Resend'), findsOneWidget);
    });
  });
}
