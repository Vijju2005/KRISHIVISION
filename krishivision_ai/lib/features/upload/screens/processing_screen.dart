import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../providers/upload_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../../core/theme/app_theme.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final int? jobId;
  const ProcessingScreen({super.key, this.jobId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  Timer? _timer;
  final _steps = [
    'Image Preprocessing',
    'NDVI Band Calculation',
    'Crop Classification',
    'Disease Detection',
    'Harvest Projection',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _startPolling();
    } else {
      // Mock simulation fallback if no jobId
      _simulateFallback();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (timer) async {
      final isDone = await ref.read(uploadProvider.notifier).pollStatus(widget.jobId!);
      if (isDone && mounted) {
        _timer?.cancel();
        // Refresh dashboard and history so new item appears immediately
        ref.invalidate(dashboardProvider);
        ref.invalidate(historyProvider);
        ref.invalidate(mapProvider);
        ref.read(historyProvider.notifier).loadHistory();
        context.pushReplacement('/results', extra: widget.jobId);
      }
    });
  }

  void _simulateFallback() async {
    // In case user landed here without a jobId, mock
    for (int progress = 0; progress <= 100; progress += 10) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // Trigger local mock state update if needed
    }
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    final progressVal = state.processingProgress / 100.0;
    final percentText = '${state.processingProgress}%';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics Progress'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  CircularPercentIndicator(
                    radius: 96,
                    lineWidth: 12,
                    percent: progressVal.clamp(0.0, 1.0),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: AppColors.primary,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          percentText,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Processing',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'AI Diagnostics Engine Running',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analyzing bands, vegetation densities, and moisture configurations from satellite capture.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Container listing analysis steps
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Column(
                      children: List.generate(_steps.length, (i) {
                        final done = i < state.stepIndex;
                        final active = i == state.stepIndex;

                        Color stepColor = isDark ? AppColors.darkTextGrey : AppColors.textGrey;
                        if (done) stepColor = AppColors.primary;
                        if (active) stepColor = isDark ? AppColors.darkText : AppColors.textDark;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 22,
                                height: 22,
                                child: done
                                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                    : active
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                          )
                                        : Icon(
                                            Icons.radio_button_off_rounded,
                                            color: isDark ? AppColors.darkBorder : AppColors.border,
                                            size: 20,
                                          ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                _steps[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                  color: stepColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
