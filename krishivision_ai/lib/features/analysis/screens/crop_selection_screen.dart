import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';

class CropSelectionScreen extends ConsumerStatefulWidget {
  final int districtId;

  const CropSelectionScreen({super.key, required this.districtId});

  @override
  ConsumerState<CropSelectionScreen> createState() => _CropSelectionScreenState();
}

class _CropSelectionScreenState extends ConsumerState<CropSelectionScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _crops = [];
  String _districtName = '';
  String _stateName = 'Karnataka';
  String? _cropsResponseSource;
  String? _emptyMessage;
  Map<String, dynamic>? _satelliteData;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  @override
  void didUpdateWidget(covariant CropSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.districtId != widget.districtId) {
      _loadCrops();
    }
  }

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _crops = [];
      _cropsResponseSource = null;
      _emptyMessage = null;
      _satelliteData = null;
      _districtName = '';
      _stateName = '';
    });

    try {
      final api = ApiClient();
      
      String distName = 'District';
      String stateName = 'Karnataka';

      // 1. Fetch district details first
      final distResp = await api.get('/map/districts/detail/${widget.districtId}');
      if (distResp.statusCode == 200) {
        distName = distResp.data['name'] ?? 'District';
        stateName = distResp.data['state_name'] ?? 'Karnataka';
        if (mounted) {
          setState(() {
            _districtName = distName;
            _stateName = stateName;
          });
        }
      }

      // 2. Fetch crops list using canonical route
      final cropsResp = await api.get('/states/${Uri.encodeComponent(stateName)}/districts/${Uri.encodeComponent(distName)}/crops');
      if (cropsResp.statusCode == 200) {
        final data = cropsResp.data;
        if (data is Map && data['status'] == 'NO_DATA') {
          _crops = [];
          _emptyMessage = 'No government crop records are available for this district.';
        } else {
          _crops = (data is Map) ? (data['crops'] ?? []) : (data ?? []);
          _cropsResponseSource = (data is Map) ? data['source'] : null;
          _emptyMessage = (data is Map) ? data['message'] : null;
          if (_crops.isEmpty) {
            _emptyMessage = 'No government crop records are available for this district.';
          }
        }
      } else {
        throw Exception('Failed to load crop details');
      }

      // 3. Fetch satellite analysis
      if (distName.isNotEmpty) {
        try {
          final satResp = await api.get('/districts/${Uri.encodeComponent(distName)}/crop-analysis');
          if (satResp.statusCode == 200) {
            _satelliteData = satResp.data;
          }
        } catch (e) {
          debugPrint('Failed to load satellite analysis: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      String msg = 'Crop data service temporarily unavailable';
      if (e is DioException) {
        msg = e.message ?? e.error?.toString() ?? 'Crop data service temporarily unavailable';
      } else {
        msg = e.toString().replaceAll('Exception: ', '');
      }

      if (msg == 'No crop data available for this district') {
        setState(() {
          _crops = [];
          _emptyMessage = 'No government crop records are available for this district.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _districtName.isNotEmpty ? '$_districtName District' : 'District Crops',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _stateName,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/map'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : _error != null
              ? _buildErrorUI()
              : _crops.isEmpty
                  ? _buildEmptyUI()
                  : _buildCropsList(isDark),
    );
  }

  Widget _buildErrorUI() {
    final isConnectionError = _error != null && 
        (_error!.contains('Unable to connect to backend') || 
         _error!.contains('Backend unavailable'));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              isConnectionError ? 'Backend unavailable' : 'Failed to Load Crops',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isConnectionError 
                  ? 'Unable to connect to the KrishiVision AI server. Check that the backend is running and your internet connection is available.'
                  : (_error ?? 'Unknown error occurred'), 
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCrops,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
            if (isConnectionError) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/api-settings'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('API Server Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grass_outlined, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'No crop data available for this district',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(_emptyMessage ?? 'No verified crop data is available for this zone.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCropsList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // District Header Info
          Text(
            _districtName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
          Text(
            _stateName,
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w600),
          ),
          if (_cropsResponseSource != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _cropsResponseSource!.toLowerCase().contains('cached')
                    ? Colors.orange.withOpacity(0.08)
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _cropsResponseSource!.toLowerCase().contains('cached')
                      ? Colors.orange.withOpacity(0.3)
                      : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cropsResponseSource!.toLowerCase().contains('cached')
                        ? Icons.cloud_off_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: _cropsResponseSource!.toLowerCase().contains('cached')
                        ? Colors.orange.shade800
                        : AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Data Source: $_cropsResponseSource',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _cropsResponseSource!.toLowerCase().contains('cached')
                          ? Colors.orange.shade800
                          : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Text(
            'Major Crops in This District',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),

          // Crops list cards
          ..._crops.map((crop) {
            final cropId = crop['id'];
            final name = crop['name'] ?? 'Unknown Crop';
            final category = crop['category'] ?? 'Commercial';
            final season = crop['season'] ?? crop['growing_season'] ?? 'Year-round';
            final importance = crop['importance'] ?? 'Major Crop';

            IconData icon = Icons.eco_rounded;
            Color color = AppColors.primary;
            if (name.toLowerCase().contains('coffee')) {
              icon = Icons.coffee_rounded;
              color = const Color(0xFF78350F);
            } else if (name.toLowerCase().contains('pepper')) {
              icon = Icons.spa_rounded;
              color = Colors.red;
            } else if (name.toLowerCase().contains('paddy') || name.toLowerCase().contains('rice')) {
              icon = Icons.grass_rounded;
              color = Colors.amber;
            } else if (name.toLowerCase().contains('cotton')) {
              icon = Icons.cloud_rounded;
              color = AppColors.info;
            } else if (name.toLowerCase().contains('maize') || name.toLowerCase().contains('wheat')) {
              icon = Icons.grain;
              color = Colors.amber.shade700;
            } else if (name.toLowerCase().contains('sugarcane')) {
              icon = Icons.spa_rounded;
              color = AppColors.cropPurple;
            } else if (name.toLowerCase().contains('coconut')) {
              icon = Icons.nature;
              color = Colors.green;
            } else if (name.toLowerCase().contains('soybean') || name.toLowerCase().contains('oilseed')) {
              icon = Icons.eco_rounded;
              color = Colors.green.shade600;
            }

            final num? areaAcres = crop['area_acres'] as num?;
            final String areaText = (areaAcres != null && areaAcres > 0.0)
                ? '${NumberFormat('#,###').format(areaAcres.round())} acres'
                : 'Statistics unreported';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ListTile(
                onTap: cropId != null 
                    ? () => context.push('/crop/$cropId') 
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Detailed analysis details unavailable for $name')),
                        );
                      },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  radius: 24,
                  child: Icon(icon, color: color, size: 24),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$category | $season',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Area: $areaText',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          importance,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: cropId != null 
                    ? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textGrey)
                    : null,
              ),
            );
          }),
          
          const SizedBox(height: 8),
          // Data source label for crops
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Source: Government of India — data.gov.in',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 2),
                Text(
                  'Status: ${_cropsResponseSource == "Cached government data" ? "CACHED" : "LIVE"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _cropsResponseSource == "Cached government data" 
                        ? Colors.orange 
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // 🛰 Satellite Analysis SECTION HEADER
          const Row(
            children: [
              Icon(Icons.satellite_alt_rounded, color: AppColors.primaryDark, size: 20),
              SizedBox(width: 8),
              Text(
                '🛰 Satellite Analysis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Satellite Analysis Card
          _buildSatelliteAnalysisCard(isDark),
        ],
      ),
    );
  }

  Widget _buildSatelliteAnalysisCard(bool isDark) {
    if (_satelliteData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No satellite data available for this district.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ),
      );
    }

    final croplandHectares = _satelliteData!['cropland_area_hectares'];
    final croplandAcres = _satelliteData!['cropland_area_acres'];
    final avgNdvi = _satelliteData!['mean_ndvi'] ?? _satelliteData!['avg_ndvi'] ?? 0.0;
    final satellite = _satelliteData!['satellite'] ?? _satelliteData!['satellite_source'] ?? 'Sentinel-2 L2A';
    final period = _satelliteData!['analysis_period'] ?? 'Current Month';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSatelliteMetricRow(
            Icons.area_chart_outlined,
            'Cropland area',
            croplandAcres != null
                ? '${NumberFormat('#,###').format(croplandAcres.round())} acres'
                : 'Unreported',
          ),
          const SizedBox(height: 12),
          _buildSatelliteMetricRow(
            Icons.eco_outlined,
            'Average NDVI',
            avgNdvi is num ? avgNdvi.toStringAsFixed(2) : avgNdvi.toString(),
          ),
          const SizedBox(height: 12),
          _buildSatelliteMetricRow(
            Icons.satellite_outlined,
            'Satellite',
            satellite,
          ),
          const SizedBox(height: 12),
          _buildSatelliteMetricRow(
            Icons.calendar_month_outlined,
            'Analysis period',
            period,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Data source: Satellite-derived',
            style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSatelliteMetricRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

