// lib/screens/home_screen.dart
import '../widgets/flood_risk_card.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static final _supabase = Supabase.instance.client;

  String? _displayName;
  String? _displayEmail;
  bool _loadingName = true;
  int _totalReports = 0;
  int _successReports = 0;
  int _pendingReports = 0;
  bool _loadingStats = true;

  // Key for the avatar widget so we can find its position
  final GlobalKey _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _loadStats();
  }

  Future<void> _loadDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _displayEmail = user.email ?? user.phoneNumber ?? '';

      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('https://bin-production-e68a.up.railway.app/profile'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _displayName = data['full_name'] ?? 'User';
            _loadingName = false;
          });
        }
      }
    } catch (e) {
      print('[Home] _loadDisplayName ERROR → $e');
      if (mounted) setState(() => _loadingName = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final reports = await Supabase.instance.client
          .from('report_submission')
          .select('status')
          .eq('user_id', user.uid);

      final list = reports as List;

      if (mounted) {
        setState(() {
          _totalReports = list.length;
          _successReports = list.where((r) => r['status'] == 'Resolved').length;
          _pendingReports = list
              .where(
                (r) => r['status'] == 'Pending' || r['status'] == 'In Progress',
              )
              .length;
          _loadingStats = false;
        });
      }
    } catch (e) {
      print('[Home] _loadStats ERROR → $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loadingName = true;
      _loadingStats = true;
    });
    await Future.wait([_loadDisplayName(), _loadStats()]);
  }

  // ── Avatar popup menu ─────────────────────────────────────────────────────

  void _showAccountMenu() {
    // Find the avatar's position on screen
    final renderBox =
        _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      color: AppTheme.bgCard,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.07)),
      ),
      // Anchor just below the avatar, aligned to its right edge
      position: RelativeRect.fromLTRB(
        offset.dx -
            180 +
            size.width, // left: push menu left so it doesn't overflow
        offset.dy + size.height + 8, // top: just below avatar
        offset.dx + size.width, // right: flush with avatar right edge
        0,
      ),
      items: [
        // ── Account info header ──────────────────────────────────────────
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini avatar
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                    ),
                    child: Center(
                      child: Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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
                          _name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_displayEmail != null && _displayEmail!.isNotEmpty)
                          Text(
                            _displayEmail!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.white.withOpacity(0.08)),
            ],
          ),
        ),

        // ── Logout ───────────────────────────────────────────────────────
        PopupMenuItem(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: _logout,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 15,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ),

        const PopupMenuItem(
          height: 8,
          enabled: false,
          child: SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    // Small delay so the menu closes cleanly before sign-out
    await Future.delayed(const Duration(milliseconds: 150));
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  String get _name => _displayName ?? 'User';
  bool get _loading => _loadingName || _loadingStats;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 20),
                    _buildMapCard(),
                    const SizedBox(height: 20),
                    const FloodRiskCard(),
                    const SizedBox(height: 20),
                    _buildTipsCard(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingNavBar(
              currentIndex: 0,
              onHome: () {},
              onCamera: () => Navigator.pushNamed(context, '/camera'),
              onTrack: () => Navigator.pushNamed(context, '/track'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _loading
                  ? Container(
                      width: 180,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.bgOverlay,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : Text(
                      'Hello, $_name',
                      style: Theme.of(context).textTheme.displayMedium,
                    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
              const SizedBox(height: 2),
              Text(
                'Help keep your community clean',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // ── Avatar with popup ─────────────────────────────────────────────
        GestureDetector(
          key: _avatarKey,
          onTap: _showAccountMenu,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          label: 'Total\nReports',
          value: _totalReports.toString(),
          color: AppTheme.primary,
          icon: Icons.delete_rounded,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Resolved',
          value: _successReports.toString(),
          color: AppTheme.success,
          icon: Icons.check_circle_rounded,
        ),
        _StatCard(
          label: 'Pending',
          value: _pendingReports.toString(),
          color: AppTheme.warning,
          icon: Icons.pending_rounded,
        ),
      ],
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06);
  }

  Widget _buildMapCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/map'),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.navBg, const Color(0xFF0F3D2E)],
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 10,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Live Trash Heatmap',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View community reports\nin real-time',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Open Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06);
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip of the Day',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A single photo report can trigger a cleanup crew. Tap the bin icon to report!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryDark.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dot Grid Painter ──────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
