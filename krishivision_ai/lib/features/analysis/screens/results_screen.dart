import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/analysis_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ResultsScreen extends ConsumerWidget {
  final int jobId;
  const ResultsScreen({super.key, required this.jobId});

  String _getImageUrl(String? localPath) {
    if (localPath == null) return '';
    final cleanPath = localPath.replaceAll('\\', '/');
    final fileName = cleanPath.split('/').last;
    final base = ApiClient().dio.options.baseUrl;
    return '$base/static/$fileName';
  }

  void _downloadReport(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(analysisResultProvider(jobId).notifier).downloadPdfReport();
    if (context.mounted) {
      if (path != null) {
        // Refresh history provider immediately
        ref.read(historyProvider.notifier).loadHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF Report generated successfully!'),
            backgroundColor: AppColors.healthy,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(path),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report generation failed. Is reportlab installed on backend?'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisResultProvider(jobId));
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing links initialized...')),
              );
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: 16),
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(analysisResultProvider(jobId).notifier).loadResult(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.grass, color: AppColors.primary, size: 36),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.result!.crop,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${state.result!.district} • ${state.result!.areaAcres} Acres',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stat grid parameters
                      Row(
                        children: [
                          Expanded(
                            child: _ResultStatTile(
                              icon: Icons.eco_outlined,
                              color: AppColors.primary,
                              label: 'Growth Stage',
                              value: state.result!.growthStage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ResultStatTile(
                              icon: Icons.favorite_border_rounded,
                              color: state.result!.healthStatus == 'Healthy' ? AppColors.healthy : AppColors.atRisk,
                              label: 'Crop Health',
                              value: state.result!.healthStatus,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultStatTile(
                              icon: Icons.calendar_today_outlined,
                              color: AppColors.info,
                              label: 'Harvest Prediction',
                              value: '${state.result!.harvestInDays} Days',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ResultStatTile(
                              icon: Icons.verified_outlined,
                              color: AppColors.primaryLight,
                              label: 'AI Confidence',
                              value: '${state.result!.confidence.round()}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '* Confidence represents agreement among the model\'s nearest reference samples and is not a guarantee of prediction accuracy.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // NDVI Map section
                      const Text(
                        'NDVI Vegetation Index Map',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Average NDVI: ${state.result!.avgNdvi} (Min: ${state.result!.minNdvi}, Max: ${state.result!.maxNdvi})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          color: isDark ? AppColors.darkCard : Colors.black12,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: _getImageUrl(state.result!.ndviImagePath),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 48, color: isDark ? AppColors.darkBorder : Colors.black26),
                                const SizedBox(height: 8),
                                const Text('No NDVI overlay loaded', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Recommendation cards
                      const Text(
                        'AI Recommendations & Actions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: state.result!.recommendations.map((rec) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    rec,
                                    style: const TextStyle(fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // Download & view map buttons
                      ElevatedButton.icon(
                        onPressed: state.isDownloadingPdf ? null : () => _downloadReport(context, ref),
                        icon: state.isDownloadingPdf
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Download PDF Report'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/map'),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open Interactive Map'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _ResultStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _ResultStatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
