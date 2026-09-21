import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/history_provider.dart';
import '../../../widgets/bottom_nav.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).loadHistory();
    });
  }

  void _showFilterModal(BuildContext context, WidgetRef ref, HistoryState state) {
    String cropSearchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCrops = state.availableCrops
                .where((c) => c.toLowerCase().contains(cropSearchQuery.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Filter & Sort History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Crop Filter dropdown
                    const Text('Crop Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search crop...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          cropSearchQuery = val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          itemCount: filteredCrops.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = filteredCrops[i];
                            final isSelected = state.filterCrop.toLowerCase() == c.toLowerCase();
                            return ListTile(
                              dense: true,
                              title: Text(c, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: AppColors.primaryDark,
                              selectedTileColor: AppColors.primaryDark.withOpacity(0.08),
                              trailing: isSelected ? const Icon(Icons.check, size: 16) : null,
                              onTap: () {
                                ref.read(historyProvider.notifier).updateFilters(crop: c);
                                setModalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Health Filter dropdown
                    const Text('Health Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: state.filterHealth,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      borderRadius: BorderRadius.circular(16),
                      items: ['All', 'Healthy', 'At Risk', 'Unhealthy']
                          .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(historyProvider.notifier).updateFilters(health: val);
                          setModalState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sort dropdown
                    const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: state.sortBy,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      borderRadius: BorderRadius.circular(16),
                      items: const [
                        DropdownMenuItem(value: 'date_desc', child: Text('Newest First')),
                        DropdownMenuItem(value: 'date_asc', child: Text('Oldest First')),
                        DropdownMenuItem(value: 'area_desc', child: Text('Largest Area')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(historyProvider.notifier).updateFilters(sort: val);
                          setModalState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadAndOpenPdf(BuildContext context, WidgetRef ref, int id, String lang, {required bool openDirectly}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Processing report request...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final api = ApiClient();
      final secureStorage = SecureStorageService();
      final token = await secureStorage.read('jwt_token');

      final directory = await getApplicationDocumentsDirectory();
      
      final historyState = ref.read(historyProvider);
      final item = historyState.rawItems.firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
      final cropName = (item['crop'] ?? 'Crop').toString().replaceAll(' ', '_');
      final district = (item['district'] ?? 'District').toString().split(',')[0].trim().replaceAll(' ', '_');
      final filePath = '${directory.path}/KrishiVision_AI_${cropName}_${district}_Report.pdf';

      await api.dio.download(
        '/analysis/$id/report?lang=$lang',
        filePath,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (openDirectly) {
        await OpenFilex.open(filePath);
      } else {
        final fileName = 'KrishiVision_AI_${cropName}_${district}_Report.pdf';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Report downloaded successfully to: $fileName'),
            backgroundColor: const Color(0xFF1B5E3A),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                OpenFilex.open(filePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to process PDF: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildCropThumbnail(String cropName, String? imageUrl, bool isDark) {
    return _buildCropImageOrFallback(cropName, isDark);
  }

  Widget _buildCropImageOrFallback(String cropName, bool isDark) {
    final String name = cropName.toLowerCase();
    String? cropImageUrl;

    if (name.contains('coffee')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=120&h=120&fit=crop';
    } else if (name.contains('rice') || name.contains('paddy')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1536304997881-a372c179924b?w=120&h=120&fit=crop';
    } else if (name.contains('maize') || name.contains('corn')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1551754625-70c904de428e?w=120&h=120&fit=crop';
    } else if (name.contains('cotton')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1598902108854-10e335adac99?w=120&h=120&fit=crop';
    } else if (name.contains('sugarcane')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1593113630400-ea4288922497?w=120&h=120&fit=crop';
    } else if (name.contains('pepper')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=120&h=120&fit=crop';
    } else if (name.contains('cardamom')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?w=120&h=120&fit=crop';
    } else if (name.contains('ginger') || name.contains('turmeric')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=120&h=120&fit=crop';
    } else if (name.contains('banana')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=120&h=120&fit=crop';
    } else if (name.contains('coconut') || name.contains('arecanut')) {
      cropImageUrl = 'https://images.unsplash.com/photo-1589244159943-460088ed5c92?w=120&h=120&fit=crop';
    }

    if (cropImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: cropImageUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallbackThumbnail(cropName),
          errorWidget: (context, url, error) => _buildFallbackThumbnail(cropName),
        ),
      );
    }
    return _buildFallbackThumbnail(cropName);
  }

  Widget _buildFallbackThumbnail(String cropName) {
    final name = cropName.toLowerCase();
    
    LinearGradient gradient;
    IconData icon;
    Color iconColor;

    if (name.contains('coffee')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF8B4513), Color(0xFFA0522D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.coffee_rounded;
      iconColor = Colors.white;
    } else if (name.contains('rice') || name.contains('paddy') || name.contains('wheat') || name.contains('grain') || name.contains('maize')) {
      gradient = const LinearGradient(
        colors: [Color(0xFFF5DEB3), Color(0xFFDEB887)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.grass_rounded;
      iconColor = const Color(0xFF5C4033);
    } else if (name.contains('tea') || name.contains('cardamom') || name.contains('pepper') || name.contains('ginger') || name.contains('turmeric') || name.contains('arecanut') || name.contains('banana') || name.contains('coconut')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.eco_rounded;
      iconColor = Colors.white;
    } else if (name.contains('apple')) {
      gradient = const LinearGradient(
        colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.apple_rounded;
      iconColor = Colors.white;
    } else if (name.contains('cotton')) {
      gradient = const LinearGradient(
        colors: [Color(0xFFECEFF1), Color(0xFFCFD8DC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.spa_rounded;
      iconColor = const Color(0xFF455A64);
    } else if (name.contains('sugarcane')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF7CB342), Color(0xFFC0CA33)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.grass_rounded;
      iconColor = Colors.white;
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFF1B5E3A), Color(0xFF2E7D32)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.spa_rounded;
      iconColor = Colors.white;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterModal(context, ref, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFECECEC)),
              ),
              child: TextField(
                onChanged: (val) => ref.read(historyProvider.notifier).updateSearch(val),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey : Colors.grey[600]),
                  hintText: 'Search by crop or district...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Filters list summary tags
          if (state.filterCrop != 'All' || state.filterHealth != 'All')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              height: 36,
              child: Row(
                children: [
                  if (state.filterCrop != 'All')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(state.filterCrop, style: const TextStyle(fontSize: 11)),
                        onDeleted: () => ref.read(historyProvider.notifier).updateFilters(crop: 'All'),
                      ),
                    ),
                  if (state.filterHealth != 'All')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(state.filterHealth, style: const TextStyle(fontSize: 11)),
                        onDeleted: () => ref.read(historyProvider.notifier).updateFilters(health: 'All'),
                      ),
                    ),
                ],
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
              color: AppColors.primary,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(state.error!, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => ref.read(historyProvider.notifier).loadHistory(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : state.filteredItems.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(40),
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off_rounded,
                                      size: 52,
                                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No records found.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Try adjusting filters or generate a new report.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              itemCount: state.filteredItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final item = state.filteredItems[i];

                                final dateString = item['created_at'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['created_at']).toLocal())
                                    : '';
                                
                                final rawLang = item['disease'] ?? 'English';
                                String displayLang = 'English';
                                String langCode = 'en';
                                if (rawLang == 'Kannada') {
                                  displayLang = 'ಕನ್ನಡ';
                                  langCode = 'kn';
                                }
                                if (rawLang == 'Hindi') {
                                  displayLang = 'हिन्दी';
                                  langCode = 'hi';
                                }

                                final areaVal = item['area_acres'];
                                final String areaText = (areaVal != null && areaVal > 0.0)
                                    ? '${NumberFormat('#,###').format(areaVal.round())} acres'
                                    : 'Area data unavailable';

                                String? imageUrl;
                                if (item['image_path'] != null && item['image_path'].toString().isNotEmpty) {
                                  final filename = item['image_path'].toString().split('/').last;
                                  imageUrl = '${ApiClient().dio.options.baseUrl}/static/$filename';
                                }

                                return Dismissible(
                                  key: Key('analysis_${item['id']}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Record'),
                                        content: const Text('Are you sure you want to permanently delete this report?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.danger,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) async {
                                    final success = await ref
                                        .read(historyProvider.notifier)
                                        .deleteAnalysis(item['id']);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success
                                              ? 'Record deleted successfully'
                                              : 'Failed to delete record'),
                                          backgroundColor: success
                                              ? AppColors.healthy
                                              : AppColors.danger,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFECECEC)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // 1. Crop image/thumbnail
                                            _buildCropThumbnail(item['crop'] ?? 'Crop', imageUrl, isDark),
                                            const SizedBox(width: 12),
                                            
                                            // 2. Report Information Column
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['crop'] ?? 'Crop',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: isDark ? Colors.white : const Color(0xFF1B5E3A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item['district'] ?? 'District, State',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? Colors.white70 : Colors.grey[700],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Area: $areaText',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? Colors.white60 : Colors.grey[800],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '📅 $dateString',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark ? Colors.white54 : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '🌐 $displayLang',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: isDark ? Colors.white54 : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Divider(height: 20, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                                        // 3. Compact Action Buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 36,
                                                child: ElevatedButton(
                                                  onPressed: () => context.push('/report/${item['id']}'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1B5E3A),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: SizedBox(
                                                height: 36,
                                                child: OutlinedButton(
                                                  onPressed: () => _downloadAndOpenPdf(context, ref, item['id'], langCode, openDirectly: false),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF1B5E3A),
                                                    side: const BorderSide(color: Color(0xFF1B5E3A), width: 1.5),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                  child: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}
