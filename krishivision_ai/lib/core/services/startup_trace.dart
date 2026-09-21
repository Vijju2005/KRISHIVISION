import 'package:flutter/foundation.dart';

class StartupTrace {
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static final Map<String, int> _timingsMs = {};
  static bool _hasReported = false;

  /// T0: Android App Process Start (Stopwatch start)
  static void markT0() {
    _timingsMs['T0 (Process Start)'] = 0;
  }

  /// T1: Flutter Engine Start
  static void markT1() {
    _timingsMs['T1 (Flutter Engine)'] = _stopwatch.elapsedMilliseconds;
    debugPrint('[StartupTrace] T1 (Flutter Engine): ${_stopwatch.elapsedMilliseconds} ms');
  }

  /// T2: main.dart Executed
  static void markT2() {
    _timingsMs['T2 (main.dart Start)'] = _stopwatch.elapsedMilliseconds;
    debugPrint('[StartupTrace] T2 (main.dart Start): ${_stopwatch.elapsedMilliseconds} ms');
  }

  /// T3: Initial Route Determined
  static void markT3(String routeName) {
    if (!_timingsMs.containsKey('T3 (Route Determined)')) {
      _timingsMs['T3 (Route Determined)'] = _stopwatch.elapsedMilliseconds;
      debugPrint('[StartupTrace] T3 (Initial Route "$routeName"): ${_stopwatch.elapsedMilliseconds} ms');
    }
  }

  /// T4: First Flutter Frame Rendered
  static void markT4() {
    if (!_timingsMs.containsKey('T4 (First Frame Rendered)')) {
      _timingsMs['T4 (First Frame Rendered)'] = _stopwatch.elapsedMilliseconds;
      debugPrint('[StartupTrace] T4 (First Frame Rendered): ${_stopwatch.elapsedMilliseconds} ms');
    }
  }

  /// T5: First Interactive Screen Becomes Usable
  static void markT5(String screenName) {
    if (!_timingsMs.containsKey('T5 (Interactive Screen Usable)')) {
      _timingsMs['T5 (Interactive Screen Usable)'] = _stopwatch.elapsedMilliseconds;
      debugPrint('[StartupTrace] T5 (Interactive Screen "$screenName"): ${_stopwatch.elapsedMilliseconds} ms');
    }
  }

  /// T6: Initial API Requests Complete
  static void markT6() {
    if (!_timingsMs.containsKey('T6 (Initial APIs Complete)')) {
      _timingsMs['T6 (Initial APIs Complete)'] = _stopwatch.elapsedMilliseconds;
      debugPrint('[StartupTrace] T6 (Initial APIs Complete): ${_stopwatch.elapsedMilliseconds} ms');
      reportSummary();
    }
  }

  /// Print full timing report summary
  static void reportSummary() {
    if (_hasReported) return;
    _hasReported = true;
    debugPrint('==================================================');
    debugPrint('       KRISHIVISION AI STARTUP PERFORMANCE        ');
    debugPrint('==================================================');
    _timingsMs.forEach((label, val) {
      debugPrint('  $label: ${val}ms');
    });
    debugPrint('==================================================');
  }

  static Map<String, int> get timings => Map.unmodifiable(_timingsMs);
}
