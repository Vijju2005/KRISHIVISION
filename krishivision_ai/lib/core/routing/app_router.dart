import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/dashboard/screens/home_screen.dart';
import '../../features/upload/screens/upload_screen.dart';
import '../../features/upload/screens/processing_screen.dart';
import '../../features/analysis/screens/results_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/settings/screens/api_settings_screen.dart';
import '../../features/analysis/screens/crop_selection_screen.dart';
import '../../features/analysis/screens/crop_detail_screen.dart';
import '../../features/analysis/screens/crop_report_detail_screen.dart';

import '../../core/services/startup_trace.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final path = state.uri.path;

      StartupTrace.markT3(path);

      if (isLoading && path != '/') return null;

      // Allow access to register, forgot password, and api-settings without being logged in
      if (!isAuthenticated) {
        if (path == '/' || path == '/login' || path == '/register' || path == '/forgot-password' || path == '/api-settings' || path == '/otp-verify') {
          return null;
        }
        return '/login';
      }

      // Logged in users shouldn't access login/register/forgot
      if (isAuthenticated) {
        if (path == '/' || path == '/login' || path == '/register' || path == '/forgot-password') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final phone = state.extra as String;
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/processing',
        builder: (context, state) {
          final jobId = state.extra as int?;
          return ProcessingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final jobId = state.extra as int;
          return ResultsScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/district/:districtId/crops',
        builder: (context, state) {
          final districtId = int.parse(state.pathParameters['districtId']!);
          return CropSelectionScreen(districtId: districtId);
        },
      ),
      GoRoute(
        path: '/crop/:cropId',
        builder: (context, state) {
          final cropId = int.parse(state.pathParameters['cropId']!);
          return CropDetailScreen(cropId: cropId);
        },
      ),
      GoRoute(
        path: '/report/:reportId',
        builder: (context, state) {
          final reportId = int.parse(state.pathParameters['reportId']!);
          return CropReportDetailScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/api-settings',
        builder: (context, state) => const ApiSettingsScreen(),
      ),
    ],
  );
});

