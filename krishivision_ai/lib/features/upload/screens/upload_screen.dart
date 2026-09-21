import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/upload_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/bottom_nav.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  void _pick(BuildContext context, WidgetRef ref, ImageSource source) async {
    final picked = await ref.read(uploadProvider.notifier).selectImage(source);
    if (!picked && context.mounted) {
      final error = ref.read(uploadProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _upload(BuildContext context, WidgetRef ref) async {
    final jobId = await ref.read(uploadProvider.notifier).uploadAndStartAnalysis();
    if (context.mounted) {
      if (jobId != null) {
        context.pushReplacement('/processing', extra: jobId);
      } else {
        final error = ref.read(uploadProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Upload failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      appBar: AppBar(
        title: const Text('Upload Satellite Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(uploadProvider.notifier).reset();
            context.go('/home');
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Analyze Field Imagery',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a satellite crop render or take a photograph to calculate NDVI overlays.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Image box selector card
                  GestureDetector(
                    onTap: state.isUploading ? null : () => _pick(context, ref, ImageSource.gallery),
                    child: Container(
                      height: 260,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: state.imagePath != null
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: state.imagePath != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.file(
                                    File(state.imagePath!),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: GestureDetector(
                                    onTap: () => ref.read(uploadProvider.notifier).reset(),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: AppColors.accentGreen,
                                  child: Icon(Icons.cloud_upload_outlined, color: AppColors.primaryDark, size: 36),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Tap to Select Image',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Supports JPG, PNG formats up to 10MB',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Button selection grid
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isUploading ? null : () => _pick(context, ref, ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isUploading ? null : () => _pick(context, ref, ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Upload button
                  if (state.imagePath != null) ...[
                    ElevatedButton(
                      onPressed: state.isUploading ? null : () => _upload(context, ref),
                      child: state.isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Start Diagnostics'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Compresses imagery to optimize bandwidth',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
