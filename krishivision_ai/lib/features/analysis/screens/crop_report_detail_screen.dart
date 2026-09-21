import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../../history/providers/history_provider.dart';

class CropReportDetailScreen extends ConsumerStatefulWidget {
  final int reportId;

  const CropReportDetailScreen({super.key, required this.reportId});

  @override
  ConsumerState<CropReportDetailScreen> createState() => _CropReportDetailScreenState();
}

class _CropReportDetailScreenState extends ConsumerState<CropReportDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _reportData = {};
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadReportDetails();
  }

  Future<void> _loadReportDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final response = await api.get('/reports/${widget.reportId}');
      if (response.statusCode == 200) {
        setState(() {
          _reportData = response.data ?? {};
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load crop report details');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  bool _isSharing = false;

  Future<String?> _getOrGeneratePdfPath(String lang) async {
    final api = ApiClient();
    final secureStorage = SecureStorageService();
    final token = await secureStorage.read('jwt_token');
    final directory = await getApplicationDocumentsDirectory();

    final cropName = (_reportData['crop_name'] ?? 'Crop').toString().replaceAll(' ', '_');
    final district = (_reportData['district'] ?? 'District').toString().split(',')[0].trim().replaceAll(' ', '_');
    final filePath = '${directory.path}/KrishiVision_AI_${cropName}_${district}_Report.pdf';

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    await api.dio.download(
      '/analysis/${widget.reportId}/report?lang=$lang',
      filePath,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return filePath;
  }

  Future<void> _downloadPdf(String lang) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await _getOrGeneratePdfPath(lang);
      setState(() {
        _isDownloading = false;
      });

      if (filePath != null && mounted) {
        final cropName = (_reportData['crop_name'] ?? 'Crop').toString().replaceAll(' ', '_');
        final district = (_reportData['district'] ?? 'District').toString().split(',')[0].trim().replaceAll(' ', '_');
        final fileName = 'KrishiVision_AI_${cropName}_${district}_Report.pdf';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to: $fileName'),
            backgroundColor: AppColors.primaryDark,
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
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final cropName = _reportData['crop_name'] ?? 'Crop';
      final district = _reportData['district'] ?? 'District';
      final filePath = await _getOrGeneratePdfPath('en'); // Default to English for sharing
      if (filePath != null) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'KrishiVision Crop Report: $cropName in $district district.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share report: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  LatLng _getCenterOfBoundary(dynamic boundaryGeoJson) {
    try {
      if (boundaryGeoJson == null) return const LatLng(15.3173, 75.7139); // Default Karnataka center
      final parsed = boundaryGeoJson is String ? jsonDecode(boundaryGeoJson) : boundaryGeoJson;
      final coords = parsed['coordinates'];
      final type = parsed['type'];
      
      double sumLat = 0;
      double sumLng = 0;
      int count = 0;
      
      if (type == 'Polygon') {
        for (final ring in coords) {
          for (final coord in ring) {
            sumLng += (coord[0] as num).toDouble();
            sumLat += (coord[1] as num).toDouble();
            count++;
          }
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          for (final ring in poly) {
            for (final coord in ring) {
              sumLng += (coord[0] as num).toDouble();
              sumLat += (coord[1] as num).toDouble();
              count++;
            }
          }
        }
      }
      
      if (count > 0) {
        return LatLng(sumLat / count, sumLng / count);
      }
    } catch (_) {}
    return const LatLng(15.3173, 75.7139);
  }

  bool get _isMapsAvailable => AppConfig.isGoogleMapsEnabled;

  List<List<LatLng>> _parseGeoJsonPolygon(dynamic boundary) {
    final List<List<LatLng>> allPolygons = [];
    if (boundary == null) return allPolygons;

    Map<String, dynamic> geom;
    if (boundary is String) {
      try {
        geom = jsonDecode(boundary);
      } catch (_) {
        return allPolygons;
      }
    } else {
      geom = Map<String, dynamic>.from(boundary);
    }

    final type = geom['type'];
    final coordinates = geom['coordinates'];
    if (coordinates == null || coordinates is! List || coordinates.isEmpty) {
      return allPolygons;
    }

    if (type == 'Polygon') {
      final ring = coordinates[0];
      if (ring is List) {
        final List<LatLng> points = [];
        for (final coord in ring) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            points.add(LatLng(lat, lng));
          }
        }
        if (points.isNotEmpty) {
          allPolygons.add(points);
        }
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in coordinates) {
        if (poly is List && poly.isNotEmpty) {
          final ring = poly[0];
          if (ring is List) {
            final List<LatLng> points = [];
            for (final coord in ring) {
              if (coord is List && coord.length >= 2) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
            if (points.isNotEmpty) {
              allPolygons.add(points);
            }
          }
        }
      }
    }
    return allPolygons;
  }

  Set<Polygon> _getPolygons(dynamic boundaryGeoJson) {
    final parsed = _parseGeoJsonPolygon(boundaryGeoJson);
    final Set<Polygon> polygonsSet = {};
    for (int i = 0; i < parsed.length; i++) {
      polygonsSet.add(
        Polygon(
          polygonId: PolygonId('district_boundary_$i'),
          points: parsed[i],
          strokeColor: Colors.cyan,
          strokeWidth: 3,
          fillColor: Colors.cyan.withOpacity(0.08),
        ),
      );
    }
    return polygonsSet;
  }

  void _fitDistrictBounds(GoogleMapController controller, dynamic boundary) {
    try {
      final polyList = _parseGeoJsonPolygon(boundary);
      if (polyList.isEmpty) return;

      double? minLat, maxLat, minLng, maxLng;
      for (final pts in polyList) {
        for (final p in pts) {
          if (minLat == null || p.latitude < minLat) minLat = p.latitude;
          if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
          if (minLng == null || p.longitude < minLng) minLng = p.longitude;
          if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
        }
      }

      if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 16.0));
      }
    } catch (_) {}
  }

  Widget _buildDistrictSatelliteSection(bool isDark) {
    final boundary = _reportData['boundary_geojson'];
    final center = _getCenterOfBoundary(boundary);
    final healthStatus = _reportData['health_status'] ?? 'Healthy';
    
    final dist = _reportData['distribution'] ?? {};
    int actualPercentage = 80;
    if (healthStatus.toLowerCase().contains('healthy')) {
      actualPercentage = dist['healthy_pct'] ?? 80;
    } else if (healthStatus.toLowerCase().contains('risk') || healthStatus.toLowerCase().contains('mod')) {
      actualPercentage = dist['moderate_pct'] ?? 50;
    } else {
      actualPercentage = dist['poor_pct'] ?? 50;
    }

    final districtName = _reportData['district'] ?? 'District';
    final cropName = _reportData['crop_name'] ?? 'Rice';
    final String cropProfile = 'Crop: $cropName | Monitored: ${_reportData['area_acres'] ?? 0.0} Acres';
    final String modelStatus = (_reportData['status'] == 'completed') ? 'Active' : 'Offline';

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: _isMapsAvailable
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: 9.0,
                      ),
                      mapType: MapType.satellite,
                      polygons: _getPolygons(boundary),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      onMapCreated: (controller) {
                        _fitDistrictBounds(controller, boundary);
                      },
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: DistrictPolygonPainter(_parseGeoJsonPolygon(boundary)),
                            ),
                          ),
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map_outlined, color: Colors.cyan, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Google Maps Satellite View Offline',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Using database boundary fallback',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10, width: 0.8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🟢 Good', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🟠 Moderate', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔴 Poor', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.65),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Health: $healthStatus ($actualPercentage%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          districtName,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'District crop profile / reported crop distribution: $cropProfile',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ML Classification: $modelStatus | Future: Sentinel-2, GEE, NDVI/EVI',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatusCard(String status) {
    Color cardColor;
    Color textColor;
    IconData icon;

    if (status.toLowerCase().contains('healthy')) {
      cardColor = AppColors.healthy.withValues(alpha: 0.1);
      textColor = AppColors.healthy;
      icon = Icons.check_circle_rounded;
    } else if (status.toLowerCase().contains('risk') || status.toLowerCase().contains('mod')) {
      cardColor = AppColors.atRisk.withValues(alpha: 0.1);
      textColor = AppColors.atRisk;
      icon = Icons.warning_rounded;
    } else {
      cardColor = AppColors.danger.withValues(alpha: 0.1);
      textColor = AppColors.danger;
      icon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Overall Status',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Crop Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('AI Powered Analysis 🌱', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark),
                  )
                : const Icon(Icons.share_rounded),
            onPressed: _isSharing ? null : _shareReport,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded),
            onSelected: (lang) => _downloadPdf(lang),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('Download English PDF')),
              PopupMenuItem(value: 'kn', child: Text('Download Kannada PDF')),
              PopupMenuItem(value: 'hi', child: Text('Download Hindi PDF')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : _error != null
              ? _buildErrorUI()
              : _buildReportContent(isDark),
    );
  }

  Widget _buildErrorUI() {
    final isConnectionError = _error != null && 
        (_error!.contains('Unable to connect to backend') || 
         _error!.contains('Backend unavailable'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              isConnectionError ? 'Backend unavailable' : 'Failed to load crop report', 
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
              onPressed: _loadReportDetails,
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

  Widget _buildReportContent(bool isDark) {
    final cropName = _reportData['crop_name'] ?? 'Sugarcane';
    final scientificName = _reportData['scientific_name'] ?? '';
    final district = _reportData['district'] ?? 'Belagavi';
    final state = _reportData['state'] ?? 'Karnataka';
    final areaVal = _reportData['area_acres'] ?? 0.0;
    final String areaText = '${NumberFormat('#,###').format(areaVal.round())} Acres';
    final growthStage = _reportData['growth_stage'] ?? 'Vegetative';
    final healthStatus = _reportData['health_status'] ?? 'Healthy';
    final ndvi = _reportData['ndvi'] ?? 0.72;
    final confidence = _reportData['confidence'] ?? 96.0;
    final estDays = _reportData['harvest_in_days'] ?? 68;

    final rawCreatedAt = _reportData['created_at'] ?? '';
    String displayDate = '';
    String displayTime = '';
    if (rawCreatedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawCreatedAt).toLocal();
        displayDate = DateFormat('dd MMM yyyy').format(dt);
        displayTime = DateFormat('hh:mm a').format(dt);
      } catch (_) {
        displayDate = DateFormat('dd MMM yyyy').format(DateTime.now());
        displayTime = DateFormat('hh:mm a').format(DateTime.now());
      }
    }

    final ndviStatus = ndvi >= 0.6 ? 'High' : (ndvi >= 0.35 ? 'Medium' : 'Low');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Location & Date Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$district District',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 2),
                    Text('$state, India', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(displayTime, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Crop Image & Selected Crop Section
          _buildDistrictSatelliteSection(isDark),
          const SizedBox(height: 14),

          Text(
            cropName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
          if (scientificName.isNotEmpty) ...[
            Text(
              scientificName,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.textGrey),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),

          // 3. Overall Health Status
          _buildHealthStatusCard(healthStatus),
          const SizedBox(height: 20),

          // 4. Satellite Analysis (Latest)
          const Text(
            'Satellite Analysis (Latest)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NDVI Index', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        Text('$ndvi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ndviStatus,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // NDVI visual scale: Low -> Medium -> High
                Row(
                  children: [
                    const Text('Low', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    Expanded(
                      child: LinearPercentIndicator(
                        lineHeight: 8.0,
                        percent: ((ndvi + 1.0) / 2.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        progressColor: AppColors.healthy,
                        barRadius: const Radius.circular(4),
                      ),
                    ),
                    const Text('High', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Key Statistics Cards
          const Text(
            'Key Statistics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Area Occupied', areaText, 'Acres', Icons.grid_on_rounded, AppColors.primary),
              _buildStatCard('Growth Stage', growthStage, 'Current Stage', Icons.energy_savings_leaf_rounded, Colors.amber),
              _buildStatCard('Estimated Harvest', 'In $estDays Days', 'Estimated', Icons.calendar_today_rounded, AppColors.info),
              _buildStatCard('AI Confidence', '${confidence.round()}%', 'Very High', Icons.verified_user_rounded, AppColors.healthy),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Crop Growth Stages Timeline
          const Text(
            'Crop Growth Stages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          _buildTimeline(growthStage),
          const SizedBox(height: 20),

          // 7. Health Metrics
          const Text(
            'Health Metrics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          _buildHealthMetricsCard(isDark),
          const SizedBox(height: 20),

          // 8. Area Distribution Section
          const Text(
            'Area Distribution',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          _buildAreaDistributionCard(isDark, areaVal),
          const SizedBox(height: 20),

          // 9. Crop Information Section
          const Text(
            'Crop Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          _buildCropInfoCard(isDark, cropName),
          const SizedBox(height: 20),

          // 10. AI Recommendations
          const Text(
            'AI Recommendations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          _buildRecommendationsCard(isDark),
          const SizedBox(height: 20),

          // 11. Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          _buildRecentActivityCard(isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String currentStage) {
    final stages = ['Planting', 'Vegetative', 'Development', 'Maturity', 'Harvest'];
    int currentIndex = stages.indexWhere((s) => s.toLowerCase() == currentStage.toLowerCase());
    if (currentIndex == -1) currentIndex = 1; // default to Vegetative

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(stages.length, (index) {
          final isCompleted = index < currentIndex;
          final isCurrent = index == currentIndex;
          final stateText = isCurrent ? ' — Current' : (isCompleted ? ' — Done' : '');

          return Row(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isCurrent ? AppColors.primaryDark : (isCompleted ? AppColors.healthy : Colors.grey[300]),
                    child: Icon(
                      isCompleted ? Icons.check : (isCurrent ? Icons.energy_savings_leaf_rounded : Icons.radio_button_unchecked),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stages[index]}$stateText',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppColors.primaryDark : (isCompleted ? AppColors.healthy : AppColors.textGrey),
                    ),
                  ),
                ],
              ),
              if (index < stages.length - 1)
                Container(
                  width: 30,
                  height: 2,
                  color: index < currentIndex ? AppColors.healthy : Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHealthMetricsCard(bool isDark) {
    final ndvi = _reportData['ndvi'] ?? 0.72;
    final evi = _reportData['evi'] ?? 0.58;
    final moisture = _reportData['moisture'] ?? 32.0;
    final temp = _reportData['temperature'] ?? 28.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMetricRow('NDVI Index', ndvi, (ndvi + 1.0) / 2.0, ndvi >= 0.6 ? 'High' : 'Moderate', AppColors.healthy),
          const Divider(height: 20),
          _buildMetricRow('EVI Index', evi, (evi + 1.0) / 2.0, evi >= 0.5 ? 'High' : 'Moderate', Colors.green),
          const Divider(height: 20),
          _buildMetricRow('Moisture Level', '$moisture%', moisture / 100.0, moisture >= 30.0 ? 'Moderate' : 'Low', AppColors.info),
          const Divider(height: 20),
          _buildMetricRow('Temperature', '$temp°C', (temp / 50.0).clamp(0.0, 1.0), 'Normal', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, dynamic value, double percent, String status, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Row(
              children: [
                Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark)),
                const SizedBox(width: 8),
                Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 6.0,
          percent: percent.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200],
          progressColor: color,
          barRadius: const Radius.circular(3),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildAreaDistributionCard(bool isDark, double totalAcres) {
    final dist = _reportData['distribution'] ?? {};
    final hAcres = dist['healthy_acres'] ?? 0.0;
    final hPct = dist['healthy_pct'] ?? 80;
    final mAcres = dist['moderate_acres'] ?? 0.0;
    final mPct = dist['moderate_pct'] ?? 15;
    final pAcres = dist['poor_acres'] ?? 0.0;
    final pPct = dist['poor_pct'] ?? 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Analyzed Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${NumberFormat('#,###').format(totalAcres.round())} Acres', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark)),
            ],
          ),
          const Divider(height: 24),
          _buildDistributionRow('Healthy Area', '${hAcres.toStringAsFixed(1)} Acres ($hPct%)', hPct / 100.0, AppColors.healthy),
          const SizedBox(height: 14),
          _buildDistributionRow('Moderate Area', '${mAcres.toStringAsFixed(1)} Acres ($mPct%)', mPct / 100.0, AppColors.atRisk),
          const SizedBox(height: 14),
          _buildDistributionRow('Poor Area', '${pAcres.toStringAsFixed(1)} Acres ($pPct%)', pPct / 100.0, AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, String detail, double fraction, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(detail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 6.0,
          percent: fraction,
          backgroundColor: Colors.grey[200],
          progressColor: color,
          barRadius: const Radius.circular(3),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildCropInfoCard(bool isDark, String cropName) {
    final cat = _reportData['category'] ?? 'Commercial';
    final season = _reportData['growing_season'] ?? 'Kharif';
    final duration = _reportData['growth_duration'] ?? '120 Days';
    final desc = _reportData['description'] ?? 'Precision agricultural monitoring';

    // Suitable parameters based on crop name
    String soil = "Loamy Clay Soil";
    String water = "Moderate (500 - 800 mm)";
    String yieldStr = "25 - 30 Tonnes / Acre";

    final nameLower = cropName.toLowerCase();
    if (nameLower.contains('coffee')) {
      soil = "Deep rich organic sandy loam";
      water = "High (1500 - 2500 mm)";
      yieldStr = "0.8 - 1.2 Tonnes / Acre";
    } else if (nameLower.contains('pepper')) {
      soil = "Humus-rich clay loam";
      water = "High (1500 - 3000 mm)";
      yieldStr = "1.5 - 2.0 Tonnes / Acre";
    } else if (nameLower.contains('cardamom')) {
      soil = "Forest loamy soils rich in humus";
      water = "High (1500 - 4000 mm)";
      yieldStr = "0.2 - 0.3 Tonnes / Acre";
    } else if (nameLower.contains('rice') || nameLower.contains('paddy')) {
      soil = "Alluvial clayey loam";
      water = "High (1200 - 1500 mm)";
      yieldStr = "2.2 - 2.8 Tonnes / Acre";
    } else if (nameLower.contains('sugarcane')) {
      soil = "Deep clayey loam";
      water = "High (1500 - 2500 mm)";
      yieldStr = "35 - 45 Tonnes / Acre";
    } else if (nameLower.contains('cotton')) {
      soil = "Black cotton soil (Regur)";
      water = "Moderate (500 - 1100 mm)";
      yieldStr = "1.2 - 1.8 Tonnes / Acre";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow('Crop Type', cat),
          _buildInfoRow('Sowing Season', season),
          _buildInfoRow('Growth Duration', duration),
          _buildInfoRow('Soil Type', soil),
          _buildInfoRow('Water Requirement', water),
          _buildInfoRow('Average Yield', yieldStr),
          if (desc.isNotEmpty) ...[
            const Divider(height: 20),
            Text(desc, style: const TextStyle(fontSize: 12, height: 1.4, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(bool isDark) {
    final list = _reportData['recommendations'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$item',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivityCard(bool isDark) {
    final list = _reportData['recent_activity'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: list.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['title'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(item['time'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DistrictPolygonPainter extends CustomPainter {
  final List<List<LatLng>> polygons;
  
  DistrictPolygonPainter(this.polygons);

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final pts in polygons) {
      for (final p in pts) {
        if (minLat == null || p.latitude < minLat) minLat = p.latitude;
        if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
        if (minLng == null || p.longitude < minLng) minLng = p.longitude;
        if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return;

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    if (latRange == 0 || lngRange == 0) return;

    final paintStroke = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintFill = Paint()
      ..color = Colors.cyan.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    // We add padding
    final double padding = 30.0;
    final double drawWidth = size.width - (padding * 2);
    final double drawHeight = size.height - (padding * 2);

    // Calculate scale to fit preserving aspect ratio
    final scale = (drawWidth / lngRange < drawHeight / latRange) 
        ? drawWidth / lngRange 
        : drawHeight / latRange;

    final xOffset = padding + (drawWidth - (lngRange * scale)) / 2;
    final yOffset = padding + (drawHeight - (latRange * scale)) / 2;

    for (final pts in polygons) {
      final path = Path();
      bool first = true;
      for (final p in pts) {
        // Map longitude to X, latitude to Y (latitude is inverted relative to Y canvas axis)
        final double x = xOffset + (p.longitude - minLng) * scale;
        final double y = yOffset + (maxLat - p.latitude) * scale;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paintFill);
      canvas.drawPath(path, paintStroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
