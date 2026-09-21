import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_client.dart';

class UploadState {
  final String? imagePath;
  final bool isUploading;
  final double uploadProgress; // 0 to 1
  final int? jobId;
  final String status; // idle, uploading, processing, completed, failed
  final int stepIndex;
  final int processingProgress; // 0 to 100
  final String? errorMessage;

  UploadState({
    this.imagePath,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.jobId,
    this.status = 'idle',
    this.stepIndex = 0,
    this.processingProgress = 0,
    this.errorMessage,
  });

  UploadState copyWith({
    String? imagePath,
    bool? isUploading,
    double? uploadProgress,
    int? jobId,
    String? status,
    int? stepIndex,
    int? processingProgress,
    String? errorMessage,
  }) {
    return UploadState(
      imagePath: imagePath ?? this.imagePath,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      stepIndex: stepIndex ?? this.stepIndex,
      processingProgress: processingProgress ?? this.processingProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final _api = ApiClient();
  final _picker = ImagePicker();

  UploadNotifier() : super(UploadState());

  Future<bool> selectImage(ImageSource source) async {
    state = UploadState(); // Reset state
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (pickedFile != null) {
        state = state.copyWith(imagePath: pickedFile.path, status: 'selected');
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to select image: ${e.toString()}');
    }
    return false;
  }

  Future<int?> uploadAndStartAnalysis() async {
    if (state.imagePath == null) {
      state = state.copyWith(errorMessage: 'No image selected');
      return null;
    }

    state = state.copyWith(isUploading: true, status: 'uploading', errorMessage: null);
    try {
      final response = await _api.uploadFile('/analysis/upload', state.imagePath!);
      final data = response.data;
      final int jobId = data['job_id'];

      state = state.copyWith(
        isUploading: false,
        jobId: jobId,
        status: 'processing',
        processingProgress: 0,
        stepIndex: 0,
      );
      return jobId;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        status: 'failed',
        errorMessage: 'Image upload failed. Is the server running?',
      );
      return null;
    }
  }

  Future<bool> pollStatus(int jobId) async {
    try {
      final response = await _api.get('/analysis/$jobId/status');
      final data = response.data;
      final int progress = data['progress'];
      final String jobStatus = data['status'];

      // Derived steps: 5 steps total
      int step = 0;
      if (progress >= 80) {
        step = 4;
      } else if (progress >= 60) {
        step = 3;
      } else if (progress >= 40) {
        step = 2;
      } else if (progress >= 20) {
        step = 1;
      }

      state = state.copyWith(
        processingProgress: progress,
        stepIndex: step,
        status: jobStatus == 'completed' ? 'completed' : 'processing',
      );

      return jobStatus == 'completed';
    } catch (e) {
      // In case of transient network error, keep polling a few times
      return false;
    }
  }

  void reset() {
    state = UploadState();
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier();
});
