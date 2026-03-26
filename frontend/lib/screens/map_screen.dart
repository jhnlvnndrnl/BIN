// lib/screens/map_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/report_model.dart';
import '../main.dart' show supabase;
import '../theme/app_theme.dart';
import '../widgets/floating_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  List<ReportModel> _reports = [];
  bool _loading = true;
  bool _mapReady = false; // ✅ track map readiness

  static const _styleUri =
      'mapbox://styles/mashiroooo/cmn2qiuhp00di01sw90fhgxka';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final res = await supabase
          .from('report_submission')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);
      final reports = (res as List)
          .map((j) => ReportModel.fromJson(j))
          .toList();
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
        // ✅ Only plot if map is already ready
        if (_mapReady) _plotHeatmap();
      }
    } catch (e) {
      print('[Map] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Zoom to current location
  Future<void> _zoomToCurrentLocation() async {
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(pos.longitude, pos.latitude),
          ), // ✅ Position here is mapbox's
          zoom: 14.0,
          pitch: 0,
        ),
        MapAnimationOptions(duration: 1200),
      );
    } catch (e) {
      print('[Map] location error: $e');
    }
  }

  Future<void> _plotHeatmap() async {
    if (_mapboxMap == null || _reports.isEmpty) return;

    for (int intensity in [1, 2, 3]) {
      final filtered = _reports.where((r) => r.intensity == intensity).toList();
      if (filtered.isEmpty) continue;

      final sourceId = 'heatmap-src-$intensity';
      final features = filtered
          .map(
            (r) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [r.long, r.lat],
              },
              'properties': {
                'id': r.id,
                'name': r.reporterName ?? '',
                'intensity': r.intensity,
                'status': r.status,
                'imageLink': r.imageLink ?? '',
                'createdAt': r.createdAt?.toIso8601String() ?? '',
              },
            },
          )
          .toList();

      final geoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': features,
      });

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: geoJson),
      );

      final colorStr = intensity == 1
          ? '#F5CB51'
          : intensity == 2
          ? '#FC8F4C'
          : '#E04154';

      final radius = intensity == 1
          ? 4.0
          : intensity == 2
          ? 8.0
          : 14.0;

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'heatmap-glow-$intensity',
          sourceId: sourceId,
          circleRadius: radius * 2.2,
          circleColor: parseColor(colorStr),
          circleOpacity: 0.20,
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'heatmap-circles-$intensity',
          sourceId: sourceId,
          circleRadius: radius,
          circleColor: parseColor(colorStr),
          circleOpacity: 0.7,
        ),
      );
    }
  }

  int parseColor(String hex) {
    final c = hex.replaceAll('#', '');
    return int.parse('FF$c', radix: 16);
  }

  void _onMapTap(MapContentGestureContext ctx) async {
    if (_mapboxMap == null) return;

    final screen = ctx.touchPosition;
    final rendered = await _mapboxMap!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenBox(
        ScreenBox(
          min: ScreenCoordinate(x: screen.x - 24, y: screen.y - 24),
          max: ScreenCoordinate(x: screen.x + 24, y: screen.y + 24),
        ),
      ),
      RenderedQueryOptions(
        layerIds: [
          'heatmap-circles-1',
          'heatmap-circles-2',
          'heatmap-circles-3',
        ],
      ),
    );

    if (rendered.isEmpty) return;
    final propsObj = rendered.first?.queriedFeature.feature['properties'];
    if (propsObj == null) return;

    final Map<String, dynamic> props;
    if (propsObj is Map) {
      props = Map<String, dynamic>.from(propsObj);
    } else {
      return;
    }

    final id = props['id']?.toString();
    final report = _reports.firstWhere(
      (r) => r.id == id,
      orElse: () => ReportModel(
        id: id ?? '',
        lat: 0,
        long: 0,
        intensity: (props['intensity'] as num?)?.toInt() ?? 1,
        reporterName: props['name']?.toString(),
        status: props['status']?.toString() ?? 'Pending',
        imageLink: props['imageLink']?.toString(),
        createdAt: props['createdAt'] != null
            ? DateTime.tryParse(props['createdAt'].toString())
            : null,
      ),
    );
    _showReportPopup(report);
  }

  void _showReportPopup(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportPopup(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MapWidget(
            styleUri: _styleUri,
            onMapCreated: (map) async {
              _mapboxMap = map;
              _mapReady = true; // ✅ mark map as ready

              // ✅ Zoom to current location first
              await _zoomToCurrentLocation();

              // ✅ Plot heatmap if reports already loaded
              if (!_loading) await _plotHeatmap();
            },
            onTapListener: _onMapTap,
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _loading
                                ? 'Loading reports...'
                                : '${_reports.length} reports found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ✅ My location button
                  GestureDetector(
                    onTap: _zoomToCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INTENSITY',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LegendItem(color: AppTheme.intensityLow, label: 'Low'),
                  const SizedBox(height: 5),
                  _LegendItem(color: AppTheme.intensityMid, label: 'Medium'),
                  const SizedBox(height: 5),
                  _LegendItem(color: AppTheme.intensityHigh, label: 'High'),
                ],
              ),
            ),
          ),

          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),

          // Floating nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingNavBar(
              currentIndex: 1,
              onHome: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              onCamera: () => Navigator.pushNamed(context, '/camera'),
              onTrack: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/track',
                (_) => false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report Popup ──────────────────────────────────────────────────────────────

class _ReportPopup extends StatelessWidget {
  final ReportModel report;
  const _ReportPopup({required this.report});

  @override
  Widget build(BuildContext context) {
    final intensityColor = report.intensity == 1
        ? AppTheme.intensityLow
        : report.intensity == 2
        ? AppTheme.intensityMid
        : AppTheme.intensityHigh;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (report.imageLink != null && report.imageLink!.isNotEmpty)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: report.imageLink!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.white.withOpacity(0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white.withOpacity(0.05),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Text(
                          (report.reporterName?.isNotEmpty == true)
                              ? report.reporterName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.reporterName ?? 'Anonymous',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (report.createdAt != null)
                            Text(
                              DateFormat(
                                'MMM d, y • h:mm a',
                              ).format(report.createdAt!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: report.status),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white10),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.delete_rounded,
                      label: '${report.intensityLabel} Intensity',
                      color: intensityColor,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.location_on_rounded,
                      label:
                          '${report.lat.toStringAsFixed(4)}, ${report.long.toStringAsFixed(4)}',
                      color: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Resolved':
        color = AppTheme.success;
        break;
      case 'In Progress':
        color = AppTheme.primary;
        break;
      default:
        color = AppTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.9),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
