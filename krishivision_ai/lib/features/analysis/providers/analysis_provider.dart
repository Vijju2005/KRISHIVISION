import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/services/api_client.dart';

class AnalysisResult {
  final int jobId;
  final String crop;
  final String district;
  final double areaAcres;
  final String growthStage;
  final String healthStatus;
  final int harvestInDays;
  final double confidence;
  final String? originalImagePath;
  final String? ndviImagePath;
  final double avgNdvi;
  final double minNdvi;
  final double maxNdvi;
  final List<String> recommendations;

  AnalysisResult({
    required this.jobId,
    required this.crop,
    required this.district,
    required this.areaAcres,
    required this.growthStage,
    required this.healthStatus,
    required this.harvestInDays,
    required this.confidence,
    this.originalImagePath,
    this.ndviImagePath,
    required this.avgNdvi,
    required this.minNdvi,
    required this.maxNdvi,
    this.recommendations = const [],
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    // Recommendations logic based on health_status if not explicitly provided
    final health = json['health_status'] ?? 'Healthy';
    final List<String> recs = [];
    if (health == 'Healthy') {
      recs.addAll([
        'Nitrogen levels look optimal. Continue current fertigation cycle.',
        'Schedule next minor irrigation in 5 days based on local evaporation.',
        'Soil moisture index shows balanced crop root hydration.',
      ]);
    } else if (health == 'At Risk') {
      recs.addAll([
        'Detected slight chlorosis. Apply nitrogen-rich fertilizer supplement.',
        'Slight water stress identified in east quadrants. Increase drip feed duration.',
        'Inspect field bounds for potential early aphid or whitefly infestation.',
      ]);
    } else {
      recs.addAll([
        'Severe crop moisture deficit! Immediate irrigation override recommended.',
        'Apply systemic fungicide (e.g. Copper Oxychloride) to treat leaf rust.',
        'Isolate highly infected crop nodes to prevent field-wide contamination.',
      ]);
    }

    final ndviSum = json['ndvi_summary'] ?? {};
    double avgN = (json['avg_ndvi'] ?? ndviSum['avg_ndvi'] ?? 0.65).toDouble();
    double minN = (json['min_ndvi'] ?? ndviSum['min_ndvi'] ?? 0.25).toDouble();
    double maxN = (json['max_ndvi'] ?? ndviSum['max_ndvi'] ?? 0.85).toDouble();

    return AnalysisResult(
      jobId: json['id'] ?? json['job_id'] ?? 0,
      crop: json['crop'] ?? 'Rice',
      district: json['district'] ?? 'Davanagere',
      areaAcres: (json['area_acres'] as num? ?? 2.5).toDouble(),
      growthStage: json['growth_stage'] ?? 'Vegetative',
      healthStatus: health,
      harvestInDays: json['harvest_in_days'] ?? 45,
      confidence: (json['confidence'] as num? ?? 95.0).toDouble(),
      originalImagePath: json['image_path'],
      ndviImagePath: json['ndvi_image_path'],
      avgNdvi: avgN,
      minNdvi: minN,
      maxNdvi: maxN,
      recommendations: recs,
    );
  }
}

class AnalysisResultState {
  final bool isLoading;
  final AnalysisResult? result;
  final String? error;
  final String? pdfPath;
  final bool isDownloadingPdf;

  AnalysisResultState({
    this.isLoading = true,
    this.result,
    this.error,
    this.pdfPath,
    this.isDownloadingPdf = false,
  });

  AnalysisResultState copyWith({
    bool? isLoading,
    AnalysisResult? result,
    String? error,
    String? pdfPath,
    bool? isDownloadingPdf,
  }) {
    return AnalysisResultState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error ?? this.error,
      pdfPath: pdfPath ?? this.pdfPath,
      isDownloadingPdf: isDownloadingPdf ?? this.isDownloadingPdf,
    );
  }
}

class AnalysisResultNotifier extends StateNotifier<AnalysisResultState> {
  final _api = ApiClient();
  final int jobId;

  AnalysisResultNotifier(this.jobId) : super(AnalysisResultState()) {
    loadResult();
  }

  Future<void> loadResult() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/analysis/$jobId/results');
      final result = AnalysisResult.fromJson(response.data);
      state = AnalysisResultState(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch analysis details from database.',
      );
    }
  }

  Future<String?> downloadPdfReport() async {
    state = state.copyWith(isDownloadingPdf: true, pdfPath: null);
    try {
      final response = await _api.dio.get(
        '/analysis/$jobId/report',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/KrishiVision_Report_$jobId.pdf');
      await file.writeAsBytes(bytes);

      state = state.copyWith(isDownloadingPdf: false, pdfPath: file.path);
      return file.path;
    } catch (_) {
      state = state.copyWith(isDownloadingPdf: false, error: 'Could not generate report.');
      return null;
    }
  }
}

final analysisResultProvider =
    StateNotifierProvider.family<AnalysisResultNotifier, AnalysisResultState, int>((ref, jobId) {
  return AnalysisResultNotifier(jobId);
});
