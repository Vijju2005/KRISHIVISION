import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../widgets/bottom_nav.dart';
import '../../auth/providers/auth_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _googleMapController;
  MapType _currentMapType = MapType.normal;

  bool _isLoading = true;
  String? _error;

  List<dynamic> _states = [];
  List<dynamic> _districts = [];

  int? _selectedStateId;
  String? _selectedStateName;
  bool _viewingDistricts = false;

  int? _selectedDistrictId;
  String? _selectedDistrictName;
  double _selectedDistrictArea = 0.0;
  List<dynamic> _districtCrops = [];
  String? _selectedDistrictCropsSource;

  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  
  // Caching systems
  final Map<String, List<List<LatLng>>> _parsedGeometryCache = {};
  final Map<String, BitmapDescriptor> _labelCache = {};

  LatLng _cameraTarget = const LatLng(22.0, 78.0); // Centered on India initially
  double _zoomLevel = 4.5; // Zoomed out for all India view

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  Future<void> _loadStates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final response = await api.get('/map/states');
      if (response.statusCode == 200) {
        setState(() {
          _states = response.data ?? [];
          _isLoading = false;
        });
        _rebuildPolygons();
      } else {
        throw Exception('Failed to load map state data');
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading states: $_error')),
        );
      }
    }
  }

  void _zoomToBoundary(dynamic boundary, {double padding = 50.0}) {
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
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    }
  }

  void _onStateTapped(int stateId, String name) {
    setState(() {
      _selectedStateId = stateId;
      _selectedStateName = name;
      _selectedDistrictId = null;
      _selectedDistrictName = null;
      _selectedDistrictCropsSource = null;
    });

    _loadDistricts(stateId);
  }

  Future<void> _loadDistricts(int stateId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _viewingDistricts = true;
    });

    try {
      final api = ApiClient();
      final response = await api.get('/map/states/$stateId/districts');
      if (response.statusCode == 200) {
        setState(() {
          _districts = response.data ?? [];
          _isLoading = false;
        });
        
        final stateData = _states.firstWhere((s) => s['id'] == stateId, orElse: () => null);
        if (stateData != null) {
          _zoomToBoundary(stateData['boundary'], padding: 40.0);
        }
        
        _rebuildPolygons();
      } else {
        throw Exception('Failed to load district data');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $_error')),
        );
      }
    }
  }

  Future<void> _selectDistrict(int districtId, String name, double area) async {
    setState(() {
      _selectedDistrictId = districtId;
      _selectedDistrictName = name;
      _selectedDistrictArea = area;
      _isLoading = true;
    });

    try {
      final api = ApiClient();
      final stateName = _selectedStateName ?? '';
      final response = await api.get('/states/${Uri.encodeComponent(stateName)}/districts/${Uri.encodeComponent(name)}/crops');
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          _districtCrops = (data is Map) ? (data['crops'] ?? []) : (data ?? []);
          _selectedDistrictCropsSource = (data is Map) ? data['source'] : null;
          if (data is Map && data.containsKey('monitored_area_acres') && data['monitored_area_acres'] != null) {
            final double apiArea = (data['monitored_area_acres'] as num).toDouble();
            if (apiArea > 0) {
              _selectedDistrictArea = apiArea;
            }
          }
          _isLoading = false;
        });

        final dist = _districts.firstWhere((d) => d['id'] == districtId, orElse: () => null);
        if (dist != null) {
          _zoomToBoundary(dist['boundary'], padding: 60.0);
        }
        _rebuildPolygons();
      } else {
        throw Exception('Failed to load crops in district');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $_error')),
        );
      }
    }
  }

  LatLng _getMultiPolygonCentroid(List<List<LatLng>> polyList) {
    if (polyList.isEmpty) return const LatLng(15.0, 75.5);

    List<LatLng> mainRing = polyList[0];
    for (final ring in polyList) {
      if (ring.length > mainRing.length) {
        mainRing = ring;
      }
    }

    if (mainRing.isEmpty) return const LatLng(15.0, 75.5);

    double minLat = mainRing[0].latitude;
    double maxLat = mainRing[0].latitude;
    double minLng = mainRing[0].longitude;
    double maxLng = mainRing[0].longitude;

    for (final p in mainRing) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLng((minLat + maxLat) / 2.0, (minLng + maxLng) / 2.0);
  }

  Future<ui.Image> _paintTextToImage(
      String text,
      double fontSize,
      ui.FontWeight fontWeight,
      Color textColor,
      Color bgColor,
      double outlineWidth) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    final Paint strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth;

    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        foreground: strokePaint,
        fontFamily: 'Inter',
      ),
    );
    textPainter.layout();

    final double textWidth = textPainter.width;
    final double textHeight = textPainter.height;
    const double paddingH = 8.0;
    const double paddingV = 4.0;

    final double boxWidth = textWidth + paddingH * 2;
    final double boxHeight = textHeight + paddingV * 2;

    // Draw background rounded container badge for readability in Satellite mode
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, boxWidth, boxHeight),
      const Radius.circular(8.0),
    );

    final Paint bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Draw text outline
    textPainter.paint(canvas, const Offset(paddingH, paddingV));

    // Draw inner fill text
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
        fontFamily: 'Inter',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(paddingH, paddingV));

    return await pictureRecorder.endRecording().toImage(
      boxWidth.round(),
      boxHeight.round(),
    );
  }

  Future<BitmapDescriptor> _getLabelIcon(String text, {required bool isSelected, required bool isDistrict}) async {
    final String cacheKey = "${text}_${isSelected}_${isDistrict}_${_currentMapType.name}";
    if (_labelCache.containsKey(cacheKey)) {
      return _labelCache[cacheKey]!;
    }

    try {
      final double fontSize = isDistrict ? 12.0 : 15.0;
      final fontWeight = isSelected ? ui.FontWeight.w900 : (isDistrict ? ui.FontWeight.w700 : ui.FontWeight.w800);
      final double outlineWidth = isDistrict ? 1.8 : 2.4;

      Color textColor;
      Color bgColor;

      if (isDistrict) {
        if (isSelected) {
          textColor = const Color(0xFF22D3EE); // Bright cyan for selected district
          bgColor = const Color(0xF20F172A);   // Dark slate background
        } else {
          textColor = Colors.white;
          bgColor = const Color(0xD91E293B);   // 85% opacity dark slate
        }
      } else {
        // State label
        if (isSelected) {
          textColor = const Color(0xFF4ADE80); // Bright emerald green for selected state
          bgColor = const Color(0xF20F172A);
        } else {
          textColor = Colors.white;
          bgColor = const Color(0xE615803D);   // Emerald green 90% opacity
        }
      }

      final ui.Image image = await _paintTextToImage(text, fontSize, fontWeight, textColor, bgColor, outlineWidth);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final icon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
        _labelCache[cacheKey] = icon;
        return icon;
      }
    } catch (e) {
      debugPrint('Error generating canvas marker label: $e');
    }
    return BitmapDescriptor.defaultMarker;
  }

  Future<void> _rebuildMarkers() async {
    final Set<Marker> newMarkers = {};

    if (_selectedStateId == null) {
      // Option A (BEST): No permanent state-name text labels on the India map.
      // Show clean geographic state boundaries. State name is displayed in top floating header when selected.
    } else {
      // Draw district markers when viewing districts under the selected state
      if (_viewingDistricts) {
        for (final d in _districts) {
          final name = d['name'] ?? 'District';
          final boundary = d['boundary'];
          final dId = (d['id'] as num).toInt();
          final cacheKey = 'district_$dId';
          final polyList = _parseGeoJsonPolygonCached(cacheKey, boundary);
          if (polyList.isEmpty) continue;

          final centroid = _getMultiPolygonCentroid(polyList);
          final isSelected = dId == _selectedDistrictId;

          final icon = await _getLabelIcon(name, isSelected: isSelected, isDistrict: true);

          newMarkers.add(
            Marker(
              markerId: MarkerId('district_label_$dId'),
              position: centroid,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              onTap: () => _selectDistrict(dId, name, (d['monitored_area'] as num? ?? 0.0).toDouble()),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  void _rebuildPolygons() {
    _polygons.clear();

    final isNormalMode = _currentMapType == MapType.normal;
    final neutralStateStroke = isNormalMode 
        ? Colors.grey.shade600.withOpacity(0.35) 
        : Colors.white.withOpacity(0.4);

    // LEVEL 1: Draw state boundaries for ALL states
    for (final s in _states) {
      final sId = (s['id'] as num).toInt();
      final sName = s['name'] ?? 'State';
      final cacheKey = 'state_$sId';
      final polyList = _parseGeoJsonPolygonCached(cacheKey, s['boundary']);

      final isThisStateSelected = sId == _selectedStateId;
      final hasSelectedDistrict = _selectedDistrictId != null;

      for (int i = 0; i < polyList.length; i++) {
        if (isThisStateSelected) {
          if (!hasSelectedDistrict) {
            // STATE SELECTED: Selected state casing & vibrant green border + subtle green fill
            _polygons.add(
              Polygon(
                polygonId: PolygonId('selected_state_${sId}_casing_$i'),
                points: polyList[i],
                strokeColor: Colors.black.withOpacity(0.5),
                fillColor: Colors.transparent,
                strokeWidth: 4,
                zIndex: 1,
              ),
            );

            _polygons.add(
              Polygon(
                polygonId: PolygonId('selected_state_${sId}_front_$i'),
                points: polyList[i],
                strokeColor: const Color(0xFF22C55E), // Bright green
                fillColor: const Color(0x1F22C55E), // Subtle 12% transparent green fill
                strokeWidth: 3,
                zIndex: 2,
                consumeTapEvents: true,
                onTap: () => _onStateTapped(sId, sName),
              ),
            );
          } else {
            // DISTRICT SELECTED: Subtle state boundary for selected state, transparent fill (no green fill over districts)
            _polygons.add(
              Polygon(
                polygonId: PolygonId('selected_state_${sId}_subtle_$i'),
                points: polyList[i],
                strokeColor: isNormalMode 
                    ? Colors.grey.shade500.withOpacity(0.35) 
                    : Colors.white.withOpacity(0.4),
                fillColor: Colors.transparent,
                strokeWidth: 1,
                zIndex: 1,
              ),
            );
          }
        } else {
          // NORMAL / UNSELECTED STATE: Clean neutral stroke, completely transparent fill (no green shading)
          _polygons.add(
            Polygon(
              polygonId: PolygonId('state_${sId}_front_$i'),
              points: polyList[i],
              strokeColor: neutralStateStroke,
              fillColor: Colors.transparent, // Completely transparent fill
              strokeWidth: 1,
              zIndex: 2,
              consumeTapEvents: true,
              onTap: () => _onStateTapped(sId, sName),
            ),
          );
        }
      }
    }

    // LEVEL 2: Draw district boundaries for the selected state
    if (_selectedStateId != null && _viewingDistricts) {
      for (final d in _districts) {
        final boundary = d['boundary'];
        final dId = (d['id'] as num).toInt();
        final isSelected = dId == _selectedDistrictId;
        final cacheKey = 'district_$dId';
        final polyList = _parseGeoJsonPolygonCached(cacheKey, boundary);

        for (int i = 0; i < polyList.length; i++) {
          if (isSelected) {
            // DISTRICT SELECTED: Casing & Cyan stroke/fill
            _polygons.add(
              Polygon(
                polygonId: PolygonId('district_${dId}_casing_$i'),
                points: polyList[i],
                strokeColor: Colors.black.withOpacity(0.7),
                fillColor: Colors.transparent,
                strokeWidth: 5,
                zIndex: 3,
              ),
            );

            _polygons.add(
              Polygon(
                polygonId: PolygonId('district_${dId}_front_$i'),
                points: polyList[i],
                strokeColor: const Color(0xFF06B6D4), // Cyan
                fillColor: const Color(0x3306B6D4),   // Transparent Cyan fill
                strokeWidth: 3,
                zIndex: 4,
                consumeTapEvents: true,
                onTap: () => _selectDistrict(dId, d['name'] ?? 'District', (d['monitored_area'] as num? ?? 0.0).toDouble()),
              ),
            );
          } else {
            // UNSELECTED DISTRICT: Subtle district boundary, completely transparent fill
            _polygons.add(
              Polygon(
                polygonId: PolygonId('district_${dId}_front_$i'),
                points: polyList[i],
                strokeColor: isNormalMode ? Colors.grey.shade600.withOpacity(0.4) : Colors.white.withOpacity(0.45),
                fillColor: Colors.transparent, // Completely transparent fill
                strokeWidth: 1,
                zIndex: 2,
                consumeTapEvents: true,
                onTap: () => _selectDistrict(dId, d['name'] ?? 'District', (d['monitored_area'] as num? ?? 0.0).toDouble()),
              ),
            );
          }
        }
      }
    }

    debugPrint('MAP DEBUG: selectedStateId=$_selectedStateId, selectedDistrictId=$_selectedDistrictId, mapType=${_currentMapType.name}, totalPolygons=${_polygons.length}');

    setState(() {});
    _rebuildMarkers();
  }

  void _handleMapTap(LatLng position) {
    // 1. If currently viewing districts, check district hit first
    if (_selectedStateId != null && _viewingDistricts && _districts.isNotEmpty) {
      for (final d in _districts) {
        final dId = (d['id'] as num).toInt();
        final cacheKey = 'district_$dId';
        final polyList = _parseGeoJsonPolygonCached(cacheKey, d['boundary']);
        if (_isPointInState(position, polyList)) {
          _selectDistrict(dId, d['name'] ?? 'District', (d['monitored_area'] as num? ?? 0.0).toDouble());
          return;
        }
      }
    }

    // 2. Otherwise (or if tap missed all districts), check state hit across all states
    for (final s in _states) {
      final sId = (s['id'] as num).toInt();
      final cacheKey = 'state_$sId';
      final polyList = _parseGeoJsonPolygonCached(cacheKey, s['boundary']);
      if (_isPointInState(position, polyList)) {
        if (sId != _selectedStateId) {
          _onStateTapped(sId, s['name'] ?? 'State');
        }
        return;
      }
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int i;
    int j = polygon.length - 1;
    bool inPoly = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      double xi = polygon[i].longitude;
      double yi = polygon[i].latitude;
      double xj = polygon[j].longitude;
      double yj = polygon[j].latitude;

      if (((yi < y && yj >= y) || (yj < y && yi >= y)) &&
          (xi + (y - yi) / (yj - yi) * (xj - xi) < x)) {
        inPoly = !inPoly;
      }
      j = i;
    }
    return inPoly;
  }

  bool _isPointInState(LatLng point, List<List<LatLng>> statePolygons) {
    for (final poly in statePolygons) {
      if (_isPointInPolygon(point, poly)) {
        return true;
      }
    }
    return false;
  }

  List<List<LatLng>> _parseGeoJsonPolygonCached(String cacheKey, dynamic boundary) {
    if (_parsedGeometryCache.containsKey(cacheKey)) {
      return _parsedGeometryCache[cacheKey]!;
    }
    final parsed = _parseGeoJsonPolygon(boundary);
    _parsedGeometryCache[cacheKey] = parsed;
    return parsed;
  }

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

  void _showMapTypeSelector() {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Map Layer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MapTypeOption(
                      type: MapType.normal,
                      label: 'Default',
                      icon: Icons.map_outlined,
                      current: _currentMapType,
                      onSelected: (type) {
                        setState(() {
                          _currentMapType = type;
                          _rebuildPolygons();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _MapTypeOption(
                      type: MapType.satellite,
                      label: 'Satellite',
                      icon: Icons.satellite_outlined,
                      current: _currentMapType,
                      onSelected: (type) {
                        setState(() {
                          _currentMapType = type;
                          _rebuildPolygons();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _MapTypeOption(
                      type: MapType.hybrid,
                      label: 'Hybrid',
                      icon: Icons.layers_rounded,
                      current: _currentMapType,
                      onSelected: (type) {
                        setState(() {
                          _currentMapType = type;
                          _rebuildPolygons();
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedStateId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_selectedDistrictId != null) {
          setState(() {
            _selectedDistrictId = null;
            _selectedDistrictName = null;
            _selectedDistrictCropsSource = null;
          });
          final stateData = _states.firstWhere((s) => (s['id'] as num).toInt() == _selectedStateId, orElse: () => null);
          if (stateData != null) {
            _zoomToBoundary(stateData['boundary'], padding: 40.0);
          }
          _rebuildPolygons();
        } else if (_selectedStateId != null) {
          setState(() {
            _selectedStateId = null;
            _selectedStateName = null;
            _viewingDistricts = false;
            _districts = [];
            _cameraTarget = const LatLng(22.0, 78.0);
            _zoomLevel = 4.5;
          });
          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_cameraTarget, _zoomLevel),
          );
          _rebuildPolygons();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        body: Stack(
          children: [
          // 1. Google Map
          Positioned.fill(
            child: GoogleMap(
              mapType: _currentMapType,
              initialCameraPosition: CameraPosition(
                target: _cameraTarget,
                zoom: _zoomLevel,
              ),
              compassEnabled: true,
              zoomControlsEnabled: false,
              polygons: _polygons,
              markers: _markers,
              onTap: _handleMapTap,
              onCameraMove: (position) {
                _zoomLevel = position.zoom;
              },
              onCameraIdle: () {
                _rebuildMarkers();
              },
              onMapCreated: (controller) {
                _googleMapController = controller;
              },
            ),
          ),

          // 2. Custom header title bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  if (_selectedStateId != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_selectedDistrictId != null) {
                          setState(() {
                            _selectedDistrictId = null;
                            _selectedDistrictName = null;
                            _selectedDistrictCropsSource = null;
                          });
                          final stateData = _states.firstWhere((s) => (s['id'] as num).toInt() == _selectedStateId, orElse: () => null);
                          if (stateData != null) {
                            _zoomToBoundary(stateData['boundary'], padding: 40.0);
                          }
                          _rebuildPolygons();
                        } else {
                          setState(() {
                            _selectedStateId = null;
                            _selectedStateName = null;
                            _viewingDistricts = false;
                            _districts = [];
                            _cameraTarget = const LatLng(22.0, 78.0);
                            _zoomLevel = 4.5;
                          });
                          _googleMapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_cameraTarget, _zoomLevel),
                          );
                          _rebuildPolygons();
                        }
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDistrictName != null
                          ? '$_selectedDistrictName District'
                          : _selectedStateName != null
                              ? '$_selectedStateName State'
                              : 'India Agriculture Map',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.layers_rounded, color: AppColors.primary),
                    onPressed: _showMapTypeSelector,
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating loading bar
          if (_isLoading)
            const Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 12),
                        Text('Updating Map...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Custom dynamic bottom sheet summary card
          if (_selectedStateId != null && !_isLoading)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildInfoCard(isDark),
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              accountName: Text(ref.watch(authProvider).fullName ?? 'Farmer'),
              accountEmail: Text(ref.watch(authProvider).email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home Dashboard'),
              onTap: () => context.go('/home'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    if (_error != null && _districts.isEmpty && _selectedDistrictId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!.contains('Backend unavailable') || _error!.contains('timeout')
                        ? 'Unable to connect to KrishiVision AI server. Please check connection and try again.'
                        : _error!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_selectedStateId != null) {
                    _loadDistricts(_selectedStateId!);
                  } else {
                    _loadStates();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedDistrictId != null) {
      // Show District detailed crops summary card (Screen 5)
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_selectedDistrictName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 2),
                      Text('$_selectedStateName State', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      if (_selectedDistrictCropsSource != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _selectedDistrictCropsSource!.toLowerCase().contains('cached')
                                  ? Icons.cloud_off_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 11,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedDistrictCropsSource!,
                              style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total APY Crop Area', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    Text(
                      '${NumberFormat('#,##,###').format(_selectedDistrictArea)} Acres',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Crops',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGrey),
                ),
                TextButton(
                  onPressed: () => context.push('/district/$_selectedDistrictId/crops'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('View All', style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Crops horizontal badges row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._districtCrops.take(3).map((c) {
                    final rawName = (c['name'] ?? c['crop_name'] ?? 'Crop').toString();
                    String name = rawName.replaceAll('&', ' & ').replaceAll(RegExp(r'\s+'), ' ').trim();
                    if (name.toLowerCase() == 'rapeseed & mustard' || name.toLowerCase().contains('rapeseed')) {
                      name = 'Rapeseed & Mustard';
                    }
                    IconData icon = Icons.eco_rounded;
                    Color color = AppColors.primary;
                    if (name.toLowerCase().contains('rice') || name.toLowerCase().contains('paddy')) {
                      icon = Icons.grass_rounded;
                      color = Colors.amber;
                    } else if (name.toLowerCase().contains('cotton')) {
                      icon = Icons.cloud_rounded;
                      color = AppColors.info;
                    } else if (name.toLowerCase().contains('maize') || name.toLowerCase().contains('millets')) {
                      icon = Icons.shopping_basket_rounded;
                      color = AppColors.atRisk;
                    } else if (name.toLowerCase().contains('sugarcane')) {
                      icon = Icons.spa_rounded;
                      color = AppColors.cropPurple;
                    }
                    return GestureDetector(
                      onTap: () => context.push('/crop/${c['id']}'),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          borderRadius: BorderRadius.circular(14),
                          color: isDark ? AppColors.darkBackground : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  (c['area_acres'] != null && (c['area_acres'] as num) > 0.0)
                                      ? '${NumberFormat('#,###').format((c['area_acres'] as num).round())} Acres'
                                      : 'Area data unavailable',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_districtCrops.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                        color: isDark ? AppColors.darkBackground : Colors.white,
                      ),
                      child: Text(
                        '+${_districtCrops.length - 3}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textGrey),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push('/district/$_selectedDistrictId/crops'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Crops in This District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_viewingDistricts) {
      // Prompt to select a district on the map (Screenshot 1 Info Card)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap any district in $_selectedStateName to view crops and statistics.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Show State basic info card (Screen 4)
      final stateData = _states.firstWhere((s) => s['id'] == _selectedStateId, orElse: () => null);
      final distCount = stateData != null ? stateData['districts_count'] ?? 0 : 0;
      final monitoredArea = stateData != null ? (stateData['monitored_area'] as num? ?? 256780.0).toDouble() : 256780.0;
      final topCrops = stateData != null ? stateData['top_crops'] ?? 'Rice, Sugarcane, Cotton' : 'Rice, Sugarcane, Cotton';

      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_selectedStateName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primaryDark),
                ),
                Text(
                  '$distCount Districts',
                  style: const TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total APY Crop Area', style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##,###').format(monitoredArea)} Acres',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Top Crops', style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      topCrops,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _loadDistricts(_selectedStateId!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Districts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.map_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _MapTypeOption extends StatelessWidget {
  final MapType type;
  final String label;
  final IconData icon;
  final MapType current;
  final ValueChanged<MapType> onSelected;

  const _MapTypeOption({
    required this.type,
    required this.label,
    required this.icon,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = type == current;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onSelected(type),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1A5D3A)
                  : (isDark ? Colors.white12 : const Color(0xFFF4F6F5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF1A5D3A) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF1A5D3A)
                  : (isDark ? Colors.white70 : AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
