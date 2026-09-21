import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

import 'core/services/startup_trace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.markT1();
  StartupTrace.markT2();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupTrace.markT4();
  });

  runApp(
    const ProviderScope(
      child: KrishiVisionApp(),
    ),
  );
}

class KrishiVisionApp extends ConsumerWidget {
  const KrishiVisionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'KrishiVision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

