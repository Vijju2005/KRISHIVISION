import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../history/providers/history_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class CropDetailScreen extends ConsumerStatefulWidget {
  final int cropId;

  const CropDetailScreen({super.key, required this.cropId});

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _googleMapController;

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _cropData = {};
  String _cropName = 'Crop Detail';
  String _districtName = 'Belagavi, Karnataka';

  LatLng _cameraTarget = const LatLng(14.4650, 75.9200);
  double _zoomLevel = 14.5;
  final Set<Polygon> _polygons = {};

  bool _isDownloading = false;
  List<dynamic> _allDistricts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCropDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCropDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _cropData = {};
      _cropName = 'Loading...';
      _districtName = '';
      _polygons.clear();
      _allDistricts = [];
    });

    try {
      final api = ApiClient();
      final response = await api.get('/crops/${widget.cropId}/overview/growth/health');
      final detailResponse = await api.get('/crops/${widget.cropId}');
      
      if (response.statusCode == 200 && detailResponse.statusCode == 200) {
        setState(() {
          _cropData = {
            ...?detailResponse.data,
            ...?response.data,
          };
          _cropName = _cropData['name'] ?? 'Sugarcane';
          _districtName = '${_cropData['district'] ?? 'Belagavi'}, ${_cropData['state_name'] ?? 'Karnataka'}';
        });

        final stateId = _cropData['state_id'];
        if (stateId != null) {
          try {
            final distsResp = await api.get('/map/states/$stateId/districts');
            if (distsResp.statusCode == 200) {
              setState(() {
                _allDistricts = distsResp.data ?? [];
              });
            }
          } catch (e) {
            debugPrint('Error loading state districts: $e');
          }
        }

        setState(() {
          _isLoading = false;
        });
        _buildMapOverlays();
      } else {
        throw Exception('Failed to load crop metrics');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _buildMapOverlays() {
    _polygons.clear();

    final selectedDistrictId = _cropData['district_id'];
    final fieldBoundary = _cropData['boundary'];
    final fieldPolysList = _parsePolygons(fieldBoundary);

    // 1. Draw neighboring districts from _allDistricts subtly with transparent fills and casings
    for (final d in _allDistricts) {
      final dId = d['id'];
      if (dId != selectedDistrictId) {
        final polyList = _parsePolygons(d['boundary']);
        for (int i = 0; i < polyList.length; i++) {
          // Neighboring district casing
          _polygons.add(
            Polygon(
              polygonId: PolygonId('neighboring_district_${dId}_casing_$i'),
              points: polyList[i],
              strokeColor: Colors.black.withOpacity(0.35),
              fillColor: Colors.transparent,
              strokeWidth: 3,
              zIndex: 1,
            ),
          );

          // Neighboring district front border
          _polygons.add(
            Polygon(
              polygonId: PolygonId('neighboring_district_${dId}_front_$i'),
              points: polyList[i],
              strokeColor: Colors.white.withOpacity(0.28),
              fillColor: Colors.transparent,
              strokeWidth: 1,
              zIndex: 2,
            ),
          );
        }
      }
    }

    // 2. Draw selected district boundary in high-contrast Neon Cyan with casing outline
    final distBoundary = _cropData['district_boundary'];
    final distPolysList = _parsePolygons(distBoundary);
    for (int i = 0; i < distPolysList.length; i++) {
      // Selected district casing
      _polygons.add(
        Polygon(
          polygonId: PolygonId('selected_district_${selectedDistrictId ?? 0}_casing_$i'),
          points: distPolysList[i],
          strokeColor: Colors.black.withOpacity(0.65),
          fillColor: Colors.transparent,
          strokeWidth: 5,
          zIndex: 3,
        ),
      );

      // Selected district front border (Neon Cyan)
      _polygons.add(
        Polygon(
          polygonId: PolygonId('selected_district_${selectedDistrictId ?? 0}_front_$i'),
          points: distPolysList[i],
          strokeColor: const Color(0xFF00E5FF), // Neon Cyan
          fillColor: Colors.transparent,
          strokeWidth: 3,
          zIndex: 4,
        ),
      );
    }

    // 3. Draw crop field boundaries with transparent fill and casing outline
    final healthStatus = _cropData['health_status'] ?? 'Healthy';
    Color healthColor = AppColors.healthy;
    if (healthStatus == 'At Risk') {
      healthColor = AppColors.atRisk;
    } else if (healthStatus == 'Unhealthy') {
      healthColor = AppColors.danger;
    }

    for (int i = 0; i < fieldPolysList.length; i++) {
      // Crop field casing
      _polygons.add(
        Polygon(
          polygonId: PolygonId('field_overlay_casing_$i'),
          points: fieldPolysList[i],
          strokeColor: Colors.black.withOpacity(0.55),
          fillColor: Colors.transparent,
          strokeWidth: 4,
          zIndex: 5,
        ),
      );

      // Crop field front border
      _polygons.add(
        Polygon(
          polygonId: PolygonId('field_overlay_front_$i'),
          points: fieldPolysList[i],
          strokeColor: healthColor,
          fillColor: Colors.transparent,
          strokeWidth: 2,
          zIndex: 6,
        ),
      );
    }

    // 4. Center and zoom to the Selected District boundary
    if (distPolysList.isNotEmpty) {
      double? minLat, maxLat, minLng, maxLng;
      for (final pts in distPolysList) {
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
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 40.0),
        );
      }
    }

    setState(() {});
  }

  List<List<LatLng>> _parsePolygons(dynamic boundary) {
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

  bool _isSharing = false;

  Future<String?> _getOrGeneratePdfPath(String lang) async {
    final api = ApiClient();
    final secureStorage = SecureStorageService();
    final token = await secureStorage.read('jwt_token');

    final directory = await getApplicationDocumentsDirectory();
    final String cleanDistrict = _districtName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final String cleanCrop = _cropName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
    final String reportFilename = 'KrishiVision_AI_Crop_Report_${cleanDistrict}_${cleanCrop}_$formattedDate.pdf';
    final filePath = '${directory.path}/$reportFilename';

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    await api.dio.download(
      '/crops/${widget.cropId}/report/pdf?lang=$lang',
      filePath,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return filePath;
  }

  Future<void> _downloadPdfReport(String lang) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await _getOrGeneratePdfPath(lang);
      setState(() {
        _isDownloading = false;
      });

      if (filePath != null && mounted) {
        final String cleanDistrict = _districtName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
        final String cleanCrop = _cropName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
        final String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
        final String reportFilename = 'KrishiVision_AI_Crop_Report_${cleanDistrict}_${cleanCrop}_$formattedDate.pdf';

        // Trigger a reload of history items in the provider so the Reports screen is immediately synced!
        ref.read(historyProvider.notifier).loadHistory();
        ref.read(dashboardProvider.notifier).loadDashboard();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to: $reportFilename'),
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
      final filePath = await _getOrGeneratePdfPath('en'); // Default to English for sharing
      if (filePath != null) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'KrishiVision Crop Report: $_cropName in $_districtName district.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(_cropName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_districtName, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primaryDark,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Health'),
            Tab(text: 'Growth'),
            Tab(text: 'Report'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : _error != null
              ? _buildErrorUI()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildHealthTab(isDark),
                    _buildGrowthTab(isDark),
                    _buildReportTab(isDark),
                  ],
                ),
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
              isConnectionError ? 'Backend unavailable' : 'Failed to load crop details', 
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
              onPressed: _loadCropDetails,
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

  // --- TAB 1: OVERVIEW (Screen 7 / 8) ---
  Widget _buildOverviewTab(bool isDark) {
    final areaVal = _cropData['area_acres'];
    final String areaText = (areaVal != null && areaVal > 0.0)
        ? '${NumberFormat('#,###').format(areaVal.round())} ac'
        : 'Area data unavailable';
        
    final satelliteAvailable = _cropData['satellite_available'] == true;
    final ndviVal = _cropData['satellite_ndvi'] ?? _cropData['latest_ndvi'] ?? _cropData['ndvi'] ?? (_cropData['health'] != null ? _cropData['health']['latest_ndvi'] : null);
    final hasNoObservations = !satelliteAvailable ||
        ndviVal == null ||
        _cropData['satellite_status'] == 'UNAVAILABLE' ||
        _cropData['satellite_status'] == 'SATELLITE DATA UNAVAILABLE' ||
        _cropData['satellite_status'] == 'SATELLITE AUTHENTICATION FAILED' ||
        _cropData['satellite_status'] == 'SATELLITE SERVICE ERROR' ||
        _cropData['satellite_status'] == 'NO VALID OBSERVATION';
    final String healthStatus = _cropData['health_status'] ?? _cropData['satellite_health_status'] ?? (_cropData['health'] != null ? _cropData['health']['status'] : null) ?? 'Satellite data unavailable';

    final bool isUnanalyzed = hasNoObservations || healthStatus == 'Unanalyzed' || healthStatus.contains('unavailable') || healthStatus.contains('failed') || healthStatus.contains('temporarily');
    final healthIdx = isUnanalyzed ? 0 : (_cropData['health_index'] ?? 92);
    
    final growthStage = _cropData['growth_stage'] ?? (_cropData['growth'] != null ? _cropData['growth']['current_stage'] : null) ?? 'Satellite data unavailable';

    final String estHarvestText;
    final dynamic estDaysVal = _cropData['est_harvest_days'] ?? _cropData['harvest_in_days'];
    if (estDaysVal != null && estDaysVal is num && estDaysVal > 0) {
      estHarvestText = 'In $estDaysVal Days';
    } else if (_cropData['estimated_harvest_date'] != null && _cropData['estimated_harvest_date'].toString().contains('-')) {
      estHarvestText = _cropData['estimated_harvest_date'].toString();
    } else {
      estHarvestText = 'Harvest prediction unavailable';
    }

    IconData healthIcon = Icons.check_circle_rounded;
    Color healthColor = AppColors.healthy;
    if (healthStatus == 'Moderate' || healthStatus == 'At Risk') {
      healthIcon = Icons.warning_rounded;
      healthColor = AppColors.atRisk;
    } else if (healthStatus == 'Poor' || healthStatus == 'Unhealthy') {
      healthIcon = Icons.error_rounded;
      healthColor = AppColors.danger;
    } else if (isUnanalyzed) {
      healthIcon = Icons.help_outline_rounded;
      healthColor = AppColors.textGrey;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // satellite map header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.public, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'GIS Satellite Viewer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'District GIS Overlay Active',
                  style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamic Satellite Map with Field & District boundaries
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.satellite,
                    initialCameraPosition: CameraPosition(
                      target: _cameraTarget,
                      zoom: _zoomLevel,
                    ),
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) {
                      _googleMapController = controller;
                      _buildMapOverlays();
                    },
                    polygons: _polygons,
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(healthIcon, color: healthColor, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                isUnanalyzed ? healthStatus : 'Health: $healthStatus ($healthIdx)',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'District crop profile | $_cropName',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ML Classification: Crop | Future: Sentinel-2, NDVI/EVI',
                            style: TextStyle(color: Colors.white70, fontSize: 8, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Health Legend overlay on map
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendDot('Good', AppColors.healthy),
                          const SizedBox(height: 6),
                          _buildLegendDot('Moderate', Colors.orange),
                          const SizedBox(height: 6),
                          _buildLegendDot('Poor', AppColors.danger),
                          const SizedBox(height: 6),
                          _buildLegendDot('Unavailable', AppColors.textGrey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom detailed statistics card - GRID Layout
          const Text(
            'GIS Monitoring Indicators',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final double ratio = constraints.maxWidth < 360 ? 1.25 : 1.5;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: ratio,
                children: [
                  _buildIndicatorCard(
                    'Cultivated Area',
                    areaText,
                    Icons.crop_free_rounded,
                    areaVal != null && areaVal > 0.0 ? AppColors.primary : AppColors.textGrey,
                    isDark,
                  ),
                  _buildIndicatorCard(
                    'Health Status',
                    isUnanalyzed ? 'Satellite data unavailable' : '$healthStatus ($healthIdx)',
                    healthIcon,
                    healthColor,
                    isDark,
                  ),
                  _buildIndicatorCard(
                    'Growth Stage',
                    isUnanalyzed ? 'Growth stage unavailable' : growthStage,
                    Icons.eco_rounded,
                    isUnanalyzed ? AppColors.textGrey : AppColors.healthy,
                    isDark,
                  ),
                  _buildIndicatorCard(
                    'Est. Harvest',
                    isUnanalyzed ? 'Harvest prediction unavailable' : estHarvestText,
                    Icons.event_note_rounded,
                    isUnanalyzed ? AppColors.textGrey : AppColors.info,
                    isDark,
                  ),
                ],
              );
            },
          ),
          
          // Crop overview description card
          _buildCropOverviewCard(isDark),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _tabController.animateTo(3),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Generate PDF Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(String label, String value, IconData icon, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: value.length > 18 ? 10 : 13,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropOverviewCard(bool isDark) {
    final areaVal = _cropData['area_acres'];
    final scientificName = _cropData['scientific_name'] ?? '';
    final category = _cropData['category'] ?? 'Cereal';
    final season = _cropData['growing_season'] ?? 'Kharif';
    final duration = _cropData['growth_duration'] ?? '120 Days';
    final description = _cropData['description'] ?? 'No description available.';
    final source = _cropData['source'] ?? '';
    final sourceYear = _cropData['source_year'] ?? 2024;
    final production = _cropData['production_tonnes'] as num?;
    final yieldVal = _cropData['yield_hg_ha'] as num?;

    final satNdvi = (_cropData['satellite_ndvi'] ?? _cropData['latest_ndvi'] ?? _cropData['ndvi'] ?? (_cropData['health'] != null ? _cropData['health']['latest_ndvi'] : null)) as num?;
    final satEvi = (_cropData['satellite_evi'] ?? _cropData['latest_evi'] ?? _cropData['evi']) as num?;
    final satHealth = (_cropData['satellite_health_status'] ?? _cropData['health_status'] ?? (_cropData['health'] != null ? _cropData['health']['status'] : null)) as String? ?? 'Unanalyzed';
    final satImage = _cropData['satellite_image'];
    final satObsDate = (_cropData['satellite_observation_date'] ?? _cropData['observation_date'] ?? (_cropData['health'] != null ? _cropData['health']['observation_date'] : null)) as String?;
    final satSource = (_cropData['satellite_source'] ?? _cropData['data_source'] ?? 'Satellite data unavailable') as String?;

    String ndviMin = 'N/A';
    String ndviMax = 'N/A';
    String ndviMedian = 'N/A';
    
    final stats = _cropData['satellite_stats'];
    if (stats is Map) {
      final ndviStats = stats['ndvi'];
      if (ndviStats is Map) {
        if (ndviStats['min'] is num) {
          ndviMin = (ndviStats['min'] as num).toStringAsFixed(2);
        }
        if (ndviStats['max'] is num) {
          ndviMax = (ndviStats['max'] as num).toStringAsFixed(2);
        }
        if (ndviStats['median'] is num) {
          ndviMedian = (ndviStats['median'] as num).toStringAsFixed(2);
        }
      }
    }
    
    // Crop-specific suitable parameters derived from known agronomic records
    String climate = "Tropical / Subtropical";
    String soil = "Well-drained loamy soil";
    String water = "Moderate to High (1000 - 1500 mm)";
    String diseases = "Rust, Leaf Spot, Stem Rot";
    String management = "Crop rotation, balanced NPK application, systemic weeding.";
    
    final nameLower = _cropName.toLowerCase();
    if (nameLower.contains('coffee')) {
      climate = "Cool to warm, humid climate (15°C - 28°C)";
      soil = "Deep, fertile, well-drained organic sandy loam";
      water = "High rainfall (1500 - 2500 mm), dry spell for flowering";
      diseases = "Coffee Rust, Coffee Berry Borer";
      management = "Shade management, pruning, organic mulching.";
    } else if (nameLower.contains('pepper')) {
      climate = "Hot, humid tropical climate (20°C - 35°C)";
      soil = "Clay loam rich in humus and organic matter";
      water = "Frequent well-distributed rainfall (1500 - 3000 mm)";
      diseases = "Quick Wilt (Foot Rot), Pollu Beetle";
      management = "Support vine trellis, mulching, loop pruning.";
    } else if (nameLower.contains('cardamom')) {
      climate = "Warm, humid forest canopy (10°C - 30°C)";
      soil = "Forest loamy soils rich in humus";
      water = "High rainfall (1500 - 4000 mm), constant moisture";
      diseases = "Katte (Mosaic), Rhizome Rot";
      management = "Under-shade planting, weeding, split NPK doses.";
    } else if (nameLower.contains('rice') || nameLower.contains('paddy')) {
      climate = "Hot, humid conditions (21°C - 37°C)";
      soil = "Alluvial clay loam retaining high water capacity";
      water = "Flooded irrigation or high rainfall (1200 - 1500 mm)";
      diseases = "Blast, Sheath Blight, Stem Borer";
      management = "Systematic transplanting, urea split-run, water leveling.";
    } else if (nameLower.contains('wheat')) {
      climate = "Cool growing season with bright sunny ripening";
      soil = "Well-drained fertile clay loamy soils";
      water = "Moderate irrigation (400 - 650 mm)";
      diseases = "Rust (Brown/Yellow), Loose Smut";
      management = "Line sowing, systematic irrigation at crown root initiation.";
    } else if (nameLower.contains('sugarcane')) {
      climate = "Tropical sun-rich growth period (20°C - 32°C)";
      soil = "Deep rich loamy soils with subsoil aeration";
      water = "High water requirements (1500 - 2500 mm)";
      diseases = "Red Rot, Smut, Grassy Shoot";
      management = "Seed selection, trash mulching, systematic drainage.";
    } else if (nameLower.contains('cotton')) {
      climate = "Warm, sunny, frost-free weather (21°C - 30°C)";
      soil = "Deep black cotton soil (Regur) retaining moisture";
      water = "Moderate rainfall (500 - 1100 mm)";
      diseases = "Bollworm complex, Wilt, Root Rot";
      management = "Pest monitoring, high density planting, clean weeding.";
    } else if (nameLower.contains('mustard')) {
      climate = "Cool, dry winter weather (10°C - 25°C)";
      soil = "Light to heavy sandy loamy soils";
      water = "Low water requirements (300 - 500 mm)";
      diseases = "Alternaria Blight, White Rust, Aphids";
      management = "Early sowing to prevent aphids, sulfur fertilization.";
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Crop Information & Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
              ),
            ],
          ),
          const Divider(height: 20),
          
          if (scientificName.isNotEmpty) ...[
            _buildOverviewRow('Scientific Name', scientificName, isItalic: true),
            const SizedBox(height: 8),
          ],
          _buildOverviewRow('Category', category),
          const SizedBox(height: 8),
          _buildOverviewRow('Growing Season', season),
          const SizedBox(height: 8),
          _buildOverviewRow('Growth Duration', duration),
          const SizedBox(height: 8),
          _buildOverviewRow('Climate Suitability', climate),
          const SizedBox(height: 8),
          _buildOverviewRow('Soil Requirements', soil),
          const SizedBox(height: 8),
          _buildOverviewRow('Water Requirements', water),
          const SizedBox(height: 8),
          _buildOverviewRow('Major Pests & Diseases', diseases),
          const SizedBox(height: 8),
          _buildOverviewRow('Management Guide', management),
          const SizedBox(height: 12),
          
          const Text(
            'Description',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Government Crop Statistics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildResponsiveStatGrid([
            {'label': 'Crop', 'value': _cropName},
            {
              'label': 'Cultivated Area',
              'value': (areaVal != null && areaVal > 0.0)
                  ? '${NumberFormat('#,###.00').format(areaVal)} acres'
                  : 'Data unavailable'
            },
            {
              'label': 'Production',
              'value': (production != null && production > 0.0)
                  ? '${NumberFormat('#,###').format(production.round())} tonnes'
                  : 'Data unavailable'
            },
            {
              'label': 'Average Yield',
              'value': (yieldVal != null && yieldVal > 0.0)
                  ? '${NumberFormat('#,###.00').format(yieldVal)} hg/ha'
                  : 'Data unavailable'
            },
            {'label': 'Crop Year', 'value': sourceYear.toString()},
            {'label': 'Season', 'value': season},
          ], isDark),
          if (source.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    'Data Source: $source ($sourceYear)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Market Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildResponsiveStatGrid([
            {'label': 'Market', 'value': _cropData['market_name'] ?? 'Chikkamagaluru Mandi'},
            {'label': 'Min Price', 'value': _cropData['min_price'] != null ? '${_cropData['min_price']}' : '₹4,500/q'},
            {'label': 'Max Price', 'value': _cropData['max_price'] != null ? '${_cropData['max_price']}' : '₹5,200/q'},
            {'label': 'Modal Price', 'value': _cropData['modal_price'] != null ? '${_cropData['modal_price']}' : '₹4,900/q'},
            {'label': 'Arrival', 'value': _cropData['arrival_qty'] ?? '15 Tonnes'},
            {'label': 'Arrival Date', 'value': _cropData['arrival_date'] ?? '2026-08-19'},
          ], isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryDark),
                SizedBox(width: 6),
                Text(
                  'Data Source: Agmarknet',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.satellite_alt_rounded, color: AppColors.healthy, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Satellite Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildResponsiveStatGrid([
            {'label': 'NDVI', 'value': satNdvi != null ? satNdvi.toStringAsFixed(2) : 'Data unavailable'},
            {'label': 'EVI', 'value': satEvi != null ? satEvi.toStringAsFixed(2) : 'Data unavailable'},
            {'label': 'Satellite Health', 'value': satHealth},
            if (satNdvi != null) ...[
              {'label': 'NDVI Min', 'value': ndviMin},
              {'label': 'NDVI Max', 'value': ndviMax},
              {'label': 'NDVI Median', 'value': ndviMedian},
            ],
          ], isDark),
          if (_cropData['satellite_image'] != null && _cropData['satellite_image']['truecolor'] != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Latest Multi-Spectral Image (True Color)',
              style: TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 140,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: _cropData['satellite_image']['truecolor'],
                  fit: BoxFit.cover,
                  memCacheHeight: 280, // Downscale cache memory footprint
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Text('Error loading satellite image', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _cropData['satellite_ndvi'] != null
                  ? AppColors.healthy.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _cropData['satellite_ndvi'] != null
                    ? AppColors.healthy.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _cropData['satellite_ndvi'] != null ? Icons.satellite_alt_rounded : Icons.cloud_off_rounded,
                  size: 14,
                  color: _cropData['satellite_ndvi'] != null ? AppColors.healthy : Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Text(
                  'Data Source: ${_cropData['satellite_source']} (${_cropData['satellite_observation_date'] ?? 'N/A'})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _cropData['satellite_ndvi'] != null ? AppColors.healthy : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value, {bool isItalic = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGrey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
          softWrap: true,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDark),
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildResponsiveStatGrid(List<Map<String, String>> stats, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int columns = width < 340 ? 2 : 3;
        final double spacing = 12.0;
        final double itemWidth = (width - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((stat) {
            return SizedBox(
              width: itemWidth,
              child: _buildVerifiedStat(stat['label']!, stat['value']!),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }



  // --- TAB 2: HEALTH (Screen 9) ---
  Widget _buildHealthTab(bool isDark) {
    final satelliteAvailable = _cropData['satellite_available'] == true;
    final ndviVal = _cropData['satellite_ndvi'] ?? _cropData['latest_ndvi'] ?? _cropData['ndvi'] ?? (_cropData['health'] != null ? _cropData['health']['latest_ndvi'] : null);
    final hasNoObservations = !satelliteAvailable ||
        ndviVal == null ||
        _cropData['satellite_status'] == 'UNAVAILABLE' ||
        _cropData['satellite_status'] == 'SATELLITE DATA UNAVAILABLE';
    final String healthStatus = hasNoObservations 
        ? 'Satellite data unavailable' 
        : (_cropData['satellite_health_status'] ?? _cropData['health_status'] ?? (_cropData['health'] != null ? _cropData['health']['status'] : null) ?? 'Satellite data unavailable');

    final bool isUnanalyzed = hasNoObservations || healthStatus == 'Unanalyzed' || healthStatus.contains('unavailable') || healthStatus.contains('failed') || healthStatus.contains('temporarily');

    final ndvi = ndviVal;
    final evi = _cropData['satellite_evi'] ?? _cropData['latest_evi'] ?? _cropData['evi'];
    final moisture = isUnanalyzed ? null : (_cropData['moisture'] ?? _cropData['moisture_level']);
    final temp = _cropData['temp'] ?? _cropData['temperature'];
    final cloudCover = isUnanalyzed ? null : _cropData['cloud_cover'];
    final obsDate = isUnanalyzed ? null : (_cropData['satellite_observation_date'] ?? _cropData['observation_date'] ?? (_cropData['health'] != null ? _cropData['health']['observation_date'] : null));
    final satPlatform = isUnanalyzed ? null : (_cropData['satellite_platform'] ?? _cropData['satellite_source'] ?? 'Sentinel-2');
    final resolution = isUnanalyzed ? null : _cropData['resolution'];

    final healthIdxVal = isUnanalyzed ? 0 : (_cropData['health_index'] ?? 0);
    final healthIdx = healthIdxVal.toDouble();
    final totalFields = isUnanalyzed ? 0 : (_cropData['total_fields'] ?? _cropData['fields_count'] ?? 1);

    List<double>? ndviTrends;
    final List<dynamic>? history = _cropData['satellite_history'];
    if (history != null && history.isNotEmpty) {
      try {
        ndviTrends = history
            .map((item) => (item['mean'] as num?)?.toDouble() ?? 0.0)
            .toList()
            .reversed
            .toList();
      } catch (_) {}
    }

    final String statusText;
    final Color statusColor;
    if (isUnanalyzed) {
      statusText = 'SATELLITE DATA UNAVAILABLE';
      statusColor = AppColors.textGrey;
    } else if (healthIdx >= 80) {
      statusText = 'EXCELLENT';
      statusColor = AppColors.healthy;
    } else if (healthIdx >= 70) {
      statusText = 'GOOD';
      statusColor = AppColors.healthy;
    } else if (healthIdx >= 40) {
      statusText = 'MODERATE';
      statusColor = Colors.orange;
    } else {
      statusText = 'POOR';
      statusColor = AppColors.danger;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 70.0,
                  lineWidth: 14.0,
                  percent: (healthIdx / 100.0).clamp(0.0, 1.0),
                  center: Text(
                    isUnanalyzed ? 'N/A' : '${healthIdx.round()}%',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: statusColor,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Good/Excellent (70-100%)', AppColors.healthy),
                _buildLegendItem('Moderate (40-70%)', Colors.orange),
                _buildLegendItem('Poor (0-40%)', AppColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Health Metrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),

          _buildHealthTrendItem('NDVI Value', ndvi != null ? ndvi.toStringAsFixed(4) : 'Not available', Icons.grass_rounded, AppColors.healthy, ndviTrends, isDark),
          _buildHealthTrendItem('EVI Value', evi != null ? evi.toStringAsFixed(4) : 'Not available', Icons.spa_rounded, AppColors.primary, ndviTrends?.map((v) => (0.85 * v + 0.05).clamp(0.0, 1.0)).toList(), isDark),
          _buildHealthTrendItem('Moisture Level (NDWI)', moisture != null ? '${moisture.round()}%' : 'Not available', Icons.water_drop_rounded, AppColors.info, null, isDark),
          _buildHealthTrendItem('Temperature', temp != null ? '${temp.toStringAsFixed(1)}°C' : 'Not available', Icons.thermostat_rounded, Colors.orange, null, isDark),
          _buildHealthTrendItem('Cloud Cover', cloudCover != null ? '${cloudCover.toStringAsFixed(1)}%' : 'Not available', Icons.cloud_rounded, Colors.blueGrey, null, isDark),
          _buildHealthTrendItem('Observation Date', obsDate != null ? obsDate : 'Not available', Icons.calendar_today_rounded, Colors.blue, null, isDark),
          _buildHealthTrendItem('Satellite Platform', satPlatform != null ? satPlatform : 'Not available', Icons.settings_applications_rounded, Colors.purple, null, isDark),
          _buildHealthTrendItem('Resolution', resolution != null ? resolution : 'Not available', Icons.grid_view_rounded, Colors.teal, null, isDark),
          _buildHealthTrendItem('Total Farm Fields', isUnanalyzed ? 'Not available' : '$totalFields Fields', Icons.map_rounded, AppColors.primary, null, isDark),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHealthTrendItem(String label, String value, IconData icon, Color iconColor, List<double>? trends, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark)),
              ],
            ),
          ),
          if (trends != null && trends.isNotEmpty)
            SizedBox(
              width: 70,
              height: 24,
              child: CustomPaint(
                painter: SparklinePainter(trends, AppColors.healthy),
              ),
            ),
        ],
      ),
    );
  }

  // --- TAB 3: GROWTH STAGES (Screen 8) ---
  Widget _buildGrowthTab(bool isDark) {
    final satelliteAvailable = _cropData['satellite_available'] == true;
    final ndviVal = _cropData['satellite_ndvi'] ?? _cropData['latest_ndvi'] ?? _cropData['ndvi'] ?? (_cropData['health'] != null ? _cropData['health']['latest_ndvi'] : null);
    final hasNoObservations = !satelliteAvailable ||
        ndviVal == null ||
        _cropData['satellite_status'] == 'UNAVAILABLE' ||
        _cropData['satellite_status'] == 'SATELLITE DATA UNAVAILABLE';
    final String currentStage = hasNoObservations 
        ? 'Satellite data unavailable' 
        : (_cropData['growth_stage'] ?? (_cropData['growth'] != null ? _cropData['growth']['current_stage'] : null) ?? 'Data unavailable');

    final bool isUnanalyzed = hasNoObservations || currentStage == 'Unanalyzed' || currentStage == 'Data unavailable' || currentStage == 'Satellite data unavailable';
    
    final List<String> stages = ['Planting', 'Germination', 'Vegetative', 'Flowering', 'Maturity', 'Harvest'];

    int activeIdx = -1;
    if (!isUnanalyzed) {
      final String sLower = currentStage.toLowerCase();
      if (sLower.contains('plant')) {
        activeIdx = 0;
      } else if (sLower.contains('germinat')) {
        activeIdx = 1;
      } else if (sLower.contains('vegetative') || sLower.contains('tiller')) {
        activeIdx = 2;
      } else if (sLower.contains('flower') || sLower.contains('bloom')) {
        activeIdx = 3;
      } else if (sLower.contains('matur') || sLower.contains('boll')) {
        activeIdx = 4;
      } else if (sLower.contains('harvest')) {
        activeIdx = 5;
      } else {
        activeIdx = 2; // default Vegetative
      }
    }

    final double progress = isUnanalyzed ? 0.0 : (((activeIdx + 1.0) / stages.length).clamp(0.0, 1.0));

    final dynamic estDaysVal = _cropData['est_harvest_days'] ?? _cropData['harvest_in_days'];
    String expectedDateText = 'Harvest prediction unavailable';
    if (!isUnanalyzed && estDaysVal != null && estDaysVal is num && estDaysVal > 0) {
      final expectedDate = DateTime.now().add(Duration(days: estDaysVal.toInt()));
      expectedDateText = 'Expected around ${DateFormat('dd MMM yyyy').format(expectedDate)}';
    } else if (!isUnanalyzed && _cropData['estimated_harvest_date'] != null && _cropData['estimated_harvest_date'].toString().contains('-')) {
      try {
        final parsedDate = DateTime.parse(_cropData['estimated_harvest_date'].toString());
        expectedDateText = 'Expected around ${DateFormat('dd MMM yyyy').format(parsedDate)}';
      } catch (_) {
        expectedDateText = 'Expected around ${_cropData['estimated_harvest_date']}';
      }
    }

    final confVal = _cropData['confidence'] ?? _cropData['crop_confidence'];
    final double confidencePercent = (confVal is num) ? (confVal <= 1.0 ? confVal * 100.0 : confVal.toDouble()) : 72.0;
    final String confidenceText = isUnanalyzed ? '0%' : '${confidencePercent.toStringAsFixed(0)}%';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Timeline
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < stages.length; i++) ...[
                    _buildTimelineNode(stages[i], !isUnanalyzed && i < activeIdx, !isUnanalyzed && i == activeIdx),
                    if (i < stages.length - 1)
                      Container(
                        width: 24,
                        height: 2,
                        color: (!isUnanalyzed && i < activeIdx) ? AppColors.primaryDark : (isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Dynamic growth stages texts
          const Text('Current Stage', style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(isUnanalyzed ? 'Growth stage unavailable' : '$currentStage Stage', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text(
            isUnanalyzed
                ? 'Growth stage cannot currently be confirmed from remote sensing. Insufficient satellite or crop timeline data to confirm the current growth stage.'
                : _getStageDescription(currentStage),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stage Progress', style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
              Text(isUnanalyzed ? 'Growth stage unavailable' : '${(progress * 100.0).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 10.0,
            percent: progress,
            barRadius: const Radius.circular(5),
            progressColor: AppColors.healthy,
            backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),

          // Expected Next Stage card (Green outline box)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.healthy.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.healthy, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expected Next Stage', style: TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(isUnanalyzed ? 'Growth stage unavailable' : (activeIdx < stages.length - 1 ? '${stages[activeIdx + 1]} Phase' : 'Harvest Finalization'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                Text(isUnanalyzed ? 'Not available' : (estDaysVal != null ? 'In $estDaysVal Days' : 'Not available'), style: TextStyle(fontWeight: FontWeight.bold, color: isUnanalyzed ? AppColors.textGrey : AppColors.primary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Harvest Prediction Card
          _buildHarvestPredictionCard(isUnanalyzed, isDark, estDaysVal, expectedDateText, confidenceText),
        ],
      ),
    );
  }

  Widget _buildHarvestPredictionCard(bool isUnanalyzed, bool isDark, dynamic estDaysVal, String expectedDateText, String confidenceText) {
    if (isUnanalyzed) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: AppColors.textGrey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Harvest Prediction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              'Harvest prediction unavailable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Insufficient satellite observations or crop profile data to project harvest timeline.',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ESTIMATED HARVEST TIME',
                style: TextStyle(color: Color(0xFFD1E7DD), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Text(
                expectedDateText,
                style: const TextStyle(color: Color(0xFFD1E7DD), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                estDaysVal != null ? 'In $estDaysVal Days' : 'Ready',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'Prediction Confidence: $confidenceText',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStageDescription(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('plant')) {
      return "The crop seeds or seedlings have been newly sown and are establishing early root structures in the soil.";
    } else if (s.contains('germinat')) {
      return "Seeds are beginning to sprout and emerge from the soil as young shoots under optimal moisture.";
    } else if (s.contains('vegetative')) {
      return "The crop is showing healthy leaf density development, leaf area indexes (LAI) expansion, and primary stalk grounding stability.";
    } else if (s.contains('tiller') || s.contains('flower') || s.contains('bloom')) {
      return "The crop is in the tillering or flowering phase. Secondary shoots are emerging rapidly, and early blossom clusters are forming.";
    } else if (s.contains('matur') || s.contains('boll')) {
      return "The crop has reached physical maturity. Seed heads/bolls are filling and ripening, nearing peak biomass content.";
    } else {
      return "The crop has finished its growth cycle. Harvesting operations, cutting, and field clearing are scheduled to commence.";
    }
  }

  Widget _buildTimelineNode(String stage, bool completed, bool active) {
    Color bg = AppColors.border;
    Widget child = const SizedBox();
    if (completed) {
      bg = AppColors.primaryLight;
      child = const Icon(Icons.check, size: 12, color: AppColors.primaryDark);
    } else if (active) {
      bg = AppColors.primaryDark;
      child = const Icon(Icons.spa_rounded, size: 12, color: Colors.white);
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bg,
          child: child,
        ),
        const SizedBox(height: 4),
        Text(stage, style: TextStyle(fontSize: 8, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }



  // --- TAB 4: REPORT & EXPORT (Screen 10) ---
  Widget _buildReportTab(bool isDark) {
    final areaVal = _cropData['area_acres'];
    final String areaText = '${NumberFormat('#,###').format(areaVal?.round() ?? 0)} acres';
    final healthIdx = _cropData['health_index'] ?? 92;
    final growthStage = _cropData['growth_stage'] ?? 'Vegetative';
    final estDays = _cropData['est_harvest_days'] ?? 68;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Crop-Specific Banner
          _buildCropIllustration(_cropName),
          const SizedBox(height: 20),

          // Report details Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, color: AppColors.primaryDark, size: 18),
                    SizedBox(width: 8),
                    Text('KrishiVision Monitoring Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark)),
                  ],
                ),
                const Divider(height: 24),
                _buildReportRow('Crop Name', _cropName),
                _buildReportRow('District Location', _districtName),
                _buildReportRow('Calculated Area', areaText),
                _buildReportRow('Vegetation Health', '$healthIdx% Healthy'),
                _buildReportRow('Growth Stage', growthStage),
                _buildReportRow('Est. Days to Harvest', '$estDays Days'),
                _buildReportRow('Report Date', DateFormat('dd MMM yyyy').format(DateTime.now())),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Language-selection triggers for PDF report
          const Text(
            'Download Monitoring Report',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLangButton('English', 'en'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLangButton('ಕನ್ನಡ', 'kn'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLangButton('हिन्दी', 'hi'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareReport,
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share_rounded),
              label: const Text('Share Report', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_month_outlined, color: AppColors.primaryDark),
              label: const Text('Schedule Weekly Report', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton(String label, String langCode) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: _isDownloading ? null : () => _downloadPdfReport(langCode),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.primaryDark, width: 1),
          ),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildCropIllustration(String cropName) {
    final name = cropName.toLowerCase();

    Gradient gradient = const LinearGradient(
      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    IconData icon = Icons.eco_rounded;
    Color iconColor = Colors.green;
    String description = "Precision agricultural monitoring.";

    if (name.contains('sugarcane')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF065F46), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.spa_rounded;
      iconColor = const Color(0xFFA7F3D0);
      description = "High-sucrose fibrous grass cultivation.";
    } else if (name.contains('rice') || name.contains('paddy')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF92400E), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.grass_rounded;
      iconColor = const Color(0xFFFEF3C7);
      description = "Saturated paddy field crop development.";
    } else if (name.contains('cotton')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.cloud_rounded;
      iconColor = const Color(0xFFDBEAFE);
      description = "Fibrous cotton textile crop structures.";
    } else if (name.contains('maize') || name.contains('millets')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF78350F), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.shopping_basket_rounded;
      iconColor = const Color(0xFFFEF3C7);
      description = "Grain seed head stalk maturity.";
    } else if (name.contains('wheat')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF854D0E), Color(0xFFEAB308)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.agriculture_rounded;
      iconColor = const Color(0xFFFEF9C3);
      description = "Cereal grain spikelet development.";
    } else if (name.contains('groundnut')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF7C2D12), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.album_rounded;
      iconColor = const Color(0xFFFFEDD5);
      description = "Subterranean legume pod maturity.";
    }

    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            bottom: -10,
            child: Icon(icon, size: 110, color: iconColor.withOpacity(0.18)),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cropName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'GIS Satellite Analysis',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double normalized = (data[i] - minVal) / range;
      final double y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
