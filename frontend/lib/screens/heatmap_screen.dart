import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://morpacoucmnubmavsxvp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vcnBhY291Y21udWJtYXZzeHZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MDU5NDQsImV4cCI6MjA4OTQ4MTk0NH0.JwKyHB66gfXhOEFZr0eiTX3OmvVfrcra4J0Gl2WbYZ4',
  );

  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoibWFzaGlyb29vbyIsImEiOiJjbW4yaHJhYzcxMjN5MnJxNDQyN25pZ2d6In0.cVitDUSPANRvrBAEUyvESw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HeatmapScreen());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single report point
// ─────────────────────────────────────────────────────────────────────────────
class ReportPoint {
  final String id;
  final double lat;
  final double long;
  final int intensity;
  final String name;
  final String? imageLink;
  final String? createdAt;

  const ReportPoint({
    required this.id,
    required this.lat,
    required this.long,
    required this.intensity,
    required this.name,
    this.imageLink,
    this.createdAt,
  });

  factory ReportPoint.fromMap(Map<String, dynamic> m) {
    return ReportPoint(
      id: m['id']?.toString() ?? '',
      lat: (m['lat'] as num).toDouble(),
      long: (m['long'] as num).toDouble(),
      intensity: (m['intensity'] as num?)?.toInt() ?? 1,
      name: m['name']?.toString() ?? 'Unknown',
      imageLink: m['image_link']?.toString(),
      createdAt: m['created_at']?.toString(),
    );
  }

  String get intensityLabel {
    switch (intensity) {
      case 1:
        return 'Low Risk';
      case 2:
        return 'Moderate Risk';
      case 3:
        return 'High Risk';
      default:
        return 'Unknown';
    }
  }

  Color get intensityColor {
    switch (intensity) {
      case 1:
        return const Color(0xFFF5CB51);
      case 2:
        return const Color(0xFFFC8F4C);
      case 3:
        return const Color(0xFFE04154);
      default:
        return Colors.grey;
    }
  }

  String get colorHex {
    switch (intensity) {
      case 1:
        return '#F5CB51';
      case 2:
        return '#FC8F4C';
      case 3:
        return '#E04154';
      default:
        return '#888888';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HeatmapScreen
// ─────────────────────────────────────────────────────────────────────────────
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});
  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  MapboxMap? mapboxMap;
  List<ReportPoint> _points = [];

  // The currently selected point (drives the bottom sheet)
  ReportPoint? _selectedPoint;

  int parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Mapbox ──────────────────────────────────────────────────────
          MapWidget(
            styleUri: "mapbox://styles/mashiroooo/cmn2qiuhp00di01sw90fhgxka",
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(121.0437, 14.6760)),
              zoom: 10,
            ),
            onMapCreated: (controller) {
              mapboxMap = controller;
              _setupTapListener();
              refreshHeatmap();
            },
          ),

          // ── Back button ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _mapIconButton(
              Icons.arrow_back_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),

          // ── Refresh button ──────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _mapIconButton(Icons.refresh_rounded, onTap: refreshHeatmap),
          ),

          // ── Legend ──────────────────────────────────────────────────────
          Positioned(
            bottom: _selectedPoint != null ? 280 : 24,
            right: 16,
            child: _buildLegend(),
          ),

          // ── Slide-up detail sheet ────────────────────────────────────────
          if (_selectedPoint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ReportDetailSheet(
                point: _selectedPoint!,
                onClose: () => setState(() => _selectedPoint = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF1A1A2E), size: 22),
      ),
    );
  }

  Widget _buildLegend() {
    final items = [
      ('Low', const Color(0xFFF5CB51)),
      ('Moderate', const Color(0xFFFC8F4C)),
      ('High', const Color(0xFFE04154)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Flood Risk',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF888888),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Setup tap listener on the map ─────────────────────────────────────────
  void _setupTapListener() {
    mapboxMap?.setOnMapTapListener((MapContentGestureContext context) {
      _handleMapTap(context.point);
    });
  }

  // ── Handle map tap: find nearest point within radius ──────────────────────
  void _handleMapTap(Point tappedPoint) {
    if (_points.isEmpty) return;

    const double tapRadiusDeg = 0.003; // ~300m tolerance

    ReportPoint? nearest;
    double nearestDist = double.infinity;

    final tapLat = tappedPoint.coordinates.lat.toDouble();
    final tapLng = tappedPoint.coordinates.lng.toDouble();

    for (final point in _points) {
      final dLat = point.lat - tapLat;
      final dLng = point.long - tapLng;
      final dist = dLat * dLat + dLng * dLng;

      if (dist < tapRadiusDeg * tapRadiusDeg && dist < nearestDist) {
        nearestDist = dist;
        nearest = point;
      }
    }

    setState(() {
      _selectedPoint = nearest; // null = dismiss sheet
    });
  }

  // ── Load + render heatmap ─────────────────────────────────────────────────
  Future<void> refreshHeatmap() async {
    final supabase = Supabase.instance.client;

    final List<Map<String, dynamic>> rows =
        (await supabase
                .from('report_submission')
                .select(
                  'id, lat, long, intensity, name, image_link, created_at',
                ))
            .cast<Map<String, dynamic>>();

    if (rows.isEmpty) return;

    // Store all points for tap detection
    _points = rows.map(ReportPoint.fromMap).toList();

    final List<Map<String, dynamic>> features = _points.map((r) {
      return {
        "type": "Feature",
        "properties": {"intensity": r.intensity, "name": r.name, "id": r.id},
        "geometry": {
          "type": "Point",
          "coordinates": [r.long, r.lat],
        },
      };
    }).toList();

    // Clean up old layers
    try {
      for (var intensity = 1; intensity <= 3; intensity++) {
        await mapboxMap?.style.removeStyleLayer("heatmap-glow-$intensity");
        await mapboxMap?.style.removeStyleLayer("heatmap-circles-$intensity");
        await mapboxMap?.style.removeStyleSource("heatpoints-$intensity");
      }
    } catch (_) {}

    final zoom = (await mapboxMap?.getCameraState())?.zoom ?? 10;
    double radius = 20;

    for (var intensity = 1; intensity <= 3; intensity++) {
      final filtered = features
          .where((f) => f['properties']['intensity'] == intensity)
          .toList();
      if (filtered.isEmpty) continue;

      final geojson = {"type": "FeatureCollection", "features": filtered};
      final sourceId = "heatpoints-$intensity";

      await mapboxMap?.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geojson)),
      );

      // Determine color by intensity
      final colorStr = intensity == 1
          ? "#F5CB51"
          : intensity == 2
          ? "#FC8F4C"
          : "#E04154";

      // Glow layer
      await mapboxMap?.style.addLayer(
        CircleLayer(
          id: "heatmap-glow-$intensity",
          sourceId: sourceId,
          circleRadius: radius * 2.2,
          circleColor: parseColor(colorStr),
          circleOpacity: 0.20,
        ),
      );

      // Main circle layer
      await mapboxMap?.style.addLayer(
        CircleLayer(
          id: "heatmap-circles-$intensity",
          sourceId: sourceId,
          circleRadius: radius,
          circleColor: parseColor(colorStr),
          circleOpacity: 0.75,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReportDetailSheet
// Slide-up bottom sheet showing details of the tapped report
// ─────────────────────────────────────────────────────────────────────────────
class _ReportDetailSheet extends StatelessWidget {
  final ReportPoint point;
  final VoidCallback onClose;

  const _ReportDetailSheet({required this.point, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.translate(offset: Offset(0, t * 260), child: child);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header row: reporter name + close
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC8A).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_circle_rounded,
                    color: Color(0xFF2ECC8A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Text(
                        'Reporter',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),

            // Info cards row
            Row(
              children: [
                _infoCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Risk Level',
                  value: point.intensityLabel,
                  color: point.intensityColor,
                ),
                const SizedBox(width: 10),
                _infoCard(
                  icon: Icons.thermostat_rounded,
                  label: 'Intensity',
                  value: '${point.intensity} / 3',
                  color: point.intensityColor,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Coordinates card
            _fullWidthInfoCard(
              icon: Icons.location_on_rounded,
              label: 'Coordinates',
              value:
                  '${point.lat.toStringAsFixed(5)}, ${point.long.toStringAsFixed(5)}',
              color: const Color(0xFF3B82F6),
            ),

            if (point.createdAt != null) ...[
              const SizedBox(height: 10),
              _fullWidthInfoCard(
                icon: Icons.access_time_rounded,
                label: 'Reported At',
                value: _formatDate(point.createdAt!),
                color: const Color(0xFF8B5CF6),
              ),
            ],

            if (point.imageLink != null && point.imageLink!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  point.imageLink!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFFCCCCCC),
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullWidthInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ampm';
    } catch (_) {
      return raw;
    }
  }
}
