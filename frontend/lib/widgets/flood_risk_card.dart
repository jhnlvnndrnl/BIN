// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/flood_risk_card.dart
//
// Refactored to act as a Thin Client.
// Fetches pre-computed DBSCAN ML predictions from the Railway FastAPI backend.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─── API Config ───────────────────────────────────────────────────────────────
// REPLACE THIS with your actual Railway deployed domain
const String backendApiUrl =
    'https://bin-admin-production-b626.up.railway.app/api/predict-flood-risk';

// ─── Model ────────────────────────────────────────────────────────────────────

class FloodRiskData {
  final String status; // UI mapped: 'Low' | 'Moderate' | 'High' | 'Critical'
  final bool isCritical;
  final double minDistanceToDrain; // metres
  final int hotspotsCount;
  final double rainMM; // mm/h
  final double widthFactor; // 0.0–1.0 for the gauge bar

  const FloodRiskData({
    required this.status,
    required this.isCritical,
    required this.minDistanceToDrain,
    required this.hotspotsCount,
    required this.rainMM,
    required this.widthFactor,
  });
}

// ─── Fetch Function (The Thin Client Integration) ─────────────────────────────

Future<FloodRiskData> fetchFloodRisk() async {
  try {
    // 1. Grab the Supabase Auth Token for secure backend calls
    // (Assuming your FastAPI backend verifies this JWT)
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';

    // 2. Make the HTTP call to your Railway Python Backend
    final response = await http
        .get(
          Uri.parse(backendApiUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Backend returned status: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    // 3. Map Python backend strings to Flutter UI strings
    final rawStatus = data['status'] as String? ?? 'Moderate Risk';
    String uiStatus = 'Moderate';
    double widthFactor = 0.55;

    if (rawStatus.contains('Low')) {
      uiStatus = 'Low';
      widthFactor = 0.20;
    } else if (rawStatus.contains('Elevated') || rawStatus.contains('High')) {
      uiStatus = 'High';
      widthFactor = 0.78;
    } else if (rawStatus.contains('CRITICAL')) {
      uiStatus = 'Critical';
      widthFactor = 1.00;
    }

    // 4. Safely parse numbers (handling Python's 'Infinity' string if no drains are nearby)
    double parsedDistance = 0.0;
    if (data['minDistanceToDrain'] is num) {
      parsedDistance = (data['minDistanceToDrain'] as num).toDouble();
    } else if (data['minDistanceToDrain'] == 'Infinity') {
      parsedDistance = double.infinity;
    }

    return FloodRiskData(
      status: uiStatus,
      isCritical: data['isCritical'] == true,
      minDistanceToDrain: parsedDistance,
      hotspotsCount: (data['hotspotsCount'] as num?)?.toInt() ?? 0,
      rainMM: (data['rainMM'] as num?)?.toDouble() ?? 0.0,
      widthFactor: widthFactor,
    );
  } catch (e) {
    debugPrint('[FloodRisk] Backend integration error: $e');
    // Fallback state if the Railway server is sleeping or fails
    throw Exception("Failed to fetch ML forecast");
  }
}

// ─── Widget (Remains largely untouched, just paints the UI) ───────────────────

class FloodRiskCard extends StatefulWidget {
  const FloodRiskCard({super.key});

  @override
  State<FloodRiskCard> createState() => _FloodRiskCardState();
}

class _FloodRiskCardState extends State<FloodRiskCard> {
  late Future<FloodRiskData> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchFloodRisk();
  }

  void _refresh() => setState(() => _future = fetchFloodRisk());

  Color _statusColor(String status) => switch (status) {
    'Low' => AppTheme.success,
    'Moderate' => AppTheme.warning,
    'High' => AppTheme.error,
    'Critical' => const Color(0xFFDC2626),
    _ => AppTheme.warning,
  };

  List<Color> _gaugeGradient(String status) => switch (status) {
    'Low' => [AppTheme.success, AppTheme.success],
    'Moderate' => [AppTheme.success, AppTheme.warning],
    'High' => [AppTheme.warning, AppTheme.error],
    'Critical' => [AppTheme.error, const Color(0xFFDC2626)],
    _ => [AppTheme.success, AppTheme.warning],
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FloodRiskData>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final data = snap.data;
        final error = snap.hasError;

        return _buildCard(context, loading: loading, data: data, error: error);
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required bool loading,
    required FloodRiskData? data,
    required bool error,
  }) {
    final status = data?.status ?? 'Moderate';
    final isCritical = data?.isCritical ?? false;
    final statusColor = _statusColor(status);
    final gauge = loading ? 0.0 : (data?.widthFactor ?? 0.55);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFF2D0A0A) : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.cardShadow,
        border: isCritical
            ? Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.35),
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCritical
                      ? const Color(0xFFDC2626).withOpacity(0.15)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.water_damage_rounded,
                  color: isCritical
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF57C00),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BIN Predictive Engine · Live API',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    'Flood Risk Forecast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const Spacer(),
              _LiveDot(critical: isCritical),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: loading ? null : _refresh,
                child: AnimatedRotation(
                  turns: loading ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: loading ? AppTheme.textMuted : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Gauge bar ──
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.bgOverlay,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedFractionallySizedBox(
                widthFactor: gauge,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: _gaugeGradient(status)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Risk tags ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RiskTag(
                label: 'Low',
                color: AppTheme.success,
                active: status == 'Low',
              ),
              _RiskTag(
                label: 'Moderate',
                color: AppTheme.warning,
                active: status == 'Moderate',
              ),
              _RiskTag(
                label: 'High',
                color: AppTheme.error,
                active: status == 'High',
              ),
              _RiskTag(
                label: 'Critical',
                color: const Color(0xFFDC2626),
                active: status == 'Critical',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Metric grid ──
          if (loading)
            _LoadingSkeleton()
          else if (error || data == null)
            _ErrorRow(onRetry: _refresh)
          else
            Column(
              children: [
                Row(
                  children: [
                    _MetricTile(
                      label: 'Risk Status',
                      value: data.status,
                      valueColor: statusColor,
                    ),
                    const SizedBox(width: 10),
                    _MetricTile(
                      label: 'Nearest Drain Risk',
                      value: data.minDistanceToDrain == double.infinity
                          ? '—'
                          : '${data.minDistanceToDrain.round()}m',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MetricTile(
                      label: 'Live Rainfall',
                      value: '${data.rainMM.toStringAsFixed(1)}',
                      unit: 'mm/h',
                    ),
                    const SizedBox(width: 10),
                    _MetricTile(
                      label: 'DBSCAN Clusters',
                      value: '${data.hotspotsCount}',
                      unit: data.hotspotsCount == 1 ? 'cluster' : 'clusters',
                      highlight: data.hotspotsCount > 0,
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 14),

          // ── Footer note ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgOverlay,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              children: [
                Icon(Icons.hub_rounded, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loading
                        ? 'Connecting to ML Engine...'
                        : error
                        ? 'Could not reach backend API. Tap ↻ to retry.'
                        : 'Predictions driven by scikit-learn DBSCAN models via Railway API.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.06);
  }
}

// ─── Sub-widgets (Unchanged from your original code) ──────────────────────────

class _LiveDot extends StatefulWidget {
  final bool critical;
  const _LiveDot({required this.critical});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.critical ? const Color(0xFFDC2626) : AppTheme.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(_anim.value),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'Server Sync',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RiskTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _RiskTag({
    required this.label,
    required this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: active ? color : AppTheme.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final bool highlight;

  const _MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFDC2626).withOpacity(0.15)
              : AppTheme.bgOverlay,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: highlight
              ? Border.all(color: const Color(0xFFDC2626).withOpacity(0.35))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
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
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        2,
        (i) => Expanded(
          child:
              Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppTheme.bgOverlay,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 1200.ms,
                    color: Colors.white.withOpacity(0.04),
                  ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load risk data.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
