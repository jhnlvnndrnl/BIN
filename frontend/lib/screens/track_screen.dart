// lib/screens/track_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/report_model.dart';
import '../main.dart' show supabase;
import '../theme/app_theme.dart';
import '../widgets/floating_nav_bar.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  List<ReportModel> _reports = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // ✅ Use Firebase UID instead of Supabase session
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final res = await supabase
          .from('report_submission') // ✅ fixed table name
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final reports = (res as List)
          .map((j) => ReportModel.fromJson(j))
          .toList();

      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      print('[Track] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ReportModel> get _filtered {
    if (_filter == 'all') return _reports;
    // ✅ match actual DB status values
    return _reports.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildFilterBar(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        )
                      : _filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _ReportCard(report: _filtered[i], index: i),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingNavBar(
              currentIndex: 2,
              onHome: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              onCamera: () => Navigator.pushNamed(context, '/camera'),
              onTrack: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // ✅ updated status strings
    final stats = {
      'total': _reports.length,
      'Resolved': _reports.where((r) => r.status == 'Resolved').length,
      'Pending': _reports.where((r) => r.status == 'Pending').length,
      'In Progress': _reports.where((r) => r.status == 'In Progress').length,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'My Reports',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryPill(
                count: stats['total']!,
                label: 'Total',
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                count: stats['Resolved']!,
                label: 'Resolved',
                color: AppTheme.success,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                count: stats['Pending']!,
                label: 'Pending',
                color: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                count: stats['In Progress']!,
                label: 'In Progress',
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              active: _filter == 'all',
              onTap: () => setState(() => _filter = 'all'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Resolved',
              active: _filter == 'Resolved',
              onTap: () => setState(() => _filter = 'Resolved'),
              color: AppTheme.success,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Pending',
              active: _filter == 'Pending',
              onTap: () => setState(() => _filter = 'Pending'),
              color: AppTheme.warning,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'In Progress',
              active: _filter == 'In Progress',
              onTap: () => setState(() => _filter = 'In Progress'),
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bgOverlay,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 32,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 'all' ? 'No reports yet' : 'No $_filter reports',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the bin icon to make your first report!',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final int index;

  const _ReportCard({required this.report, required this.index});

  // ✅ updated status colors
  Color get _statusColor {
    switch (report.status) {
      case 'Resolved':
        return AppTheme.success;
      case 'In Progress':
        return AppTheme.primary;
      default:
        return AppTheme.warning; // Pending
    }
  }

  IconData get _statusIcon {
    switch (report.status) {
      case 'Resolved':
        return Icons.check_circle_rounded;
      case 'In Progress':
        return Icons.autorenew_rounded;
      default:
        return Icons.pending_rounded; // Pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: AppTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Image thumbnail
              SizedBox(
                width: 90,
                height: 90,
                child: report.imageLink != null && report.imageLink!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: report.imageLink!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.bgOverlay,
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.bgOverlay,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: AppTheme.textMuted,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        color: AppTheme.bgOverlay,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: AppTheme.textMuted,
                          size: 24,
                        ),
                      ),
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon,
                                  color: _statusColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  report.status, // ✅ show raw status directly
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${report.lat.toStringAsFixed(5)}, ${report.long.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.createdAt != null
                                ? DateFormat(
                                    'MMM d, y',
                                  ).format(report.createdAt!)
                                : 'Unknown date',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn()
        .slideX(begin: 0.04);
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SummaryPill({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          boxShadow: active ? [] : AppTheme.cardShadow,
          border: Border.all(color: active ? activeColor : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
