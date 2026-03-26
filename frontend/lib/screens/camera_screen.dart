// lib/screens/camera_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show supabase;
import '../theme/app_theme.dart';

enum UploadState { idle, capturing, uploading, success, failure }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  UploadState _state = UploadState.idle;
  File? _capturedFile;
  double _zoomLevel = 1.0;
  bool _flashOn = false;
  bool _frontCamera = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _setupCamera(_frontCamera ? 1 : 0);
  }

  Future<void> _setupCamera(int idx) async {
    if (idx >= _cameras.length) idx = 0;
    final ctrl = CameraController(
      _cameras[idx],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    await ctrl.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(_frontCamera ? 1 : 0);
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_state != UploadState.idle) return;

    HapticFeedback.heavyImpact();
    setState(() => _state = UploadState.capturing);

    try {
      final xfile = await _controller!.takePicture();
      setState(() {
        _capturedFile = File(xfile.path);
        _state = UploadState.idle;
      });
      _showPreviewSheet();
    } catch (e) {
      setState(() {
        _state = UploadState.idle;
        _errorMsg = 'Capture failed';
      });
    }
  }

  void _showPreviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewSheet(
        image: _capturedFile!,
        onConfirm: _upload, // no intensity arg
        onRetake: () {
          Navigator.pop(context);
          setState(() => _capturedFile = null);
        },
      ),
    );
  }

  Future<void> _upload() async {
    if (_capturedFile == null) return;
    Navigator.pop(context); // close preview sheet
    setState(() => _state = UploadState.uploading);

    try {
      // ✅ Check & request location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _state = UploadState.failure;
            _errorMsg = 'Location permission is required to submit a report.';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        setState(() {
          _state = UploadState.failure;
          _errorMsg =
              'Location permission permanently denied. Please enable it in Settings.';
        });
        return;
      }

      // Get location
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get Firebase user
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userId = firebaseUser?.uid;

      // Get name from backend
      String name = 'Anonymous';
      if (firebaseUser != null) {
        try {
          final idToken = await firebaseUser.getIdToken();
          final res = await http.get(
            Uri.parse('https://bin-production-e68a.up.railway.app/profile'),
            headers: {'Authorization': 'Bearer $idToken'},
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            name = data['full_name'] ?? 'Anonymous';
          }
        } catch (e) {
          print('[Camera] profile fetch error: $e');
        }
      }

      // Upload image
      final fileName = '${const Uuid().v4()}.jpg';
      final bytes = await _capturedFile!.readAsBytes();
      await supabase.storage
          .from('test_storage')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final imageLink = supabase.storage
          .from('test_storage')
          .getPublicUrl(fileName);

      // Insert report
      await supabase.from('report_submission').insert({
        'image_link': imageLink,
        'lat': pos.latitude,
        'long': pos.longitude,
        'name': name,
        'user_id': userId,
      });

      setState(() => _state = UploadState.success);
    } catch (e) {
      print('[Camera] upload error: $e');
      setState(() {
        _state = UploadState.failure;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == UploadState.success) {
      return _ResultScreen(
        success: true,
        onDone: () =>
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
      );
    }
    if (_state == UploadState.failure) {
      return _ResultScreen(
        success: false,
        errorMsg: _errorMsg,
        onDone: () => setState(() {
          _state = UploadState.idle;
          _capturedFile = null;
        }),
      );
    }

    if (_state == UploadState.uploading) {
      return const _UploadingScreen();
    }

    return _buildCameraView();
  }

  Widget _buildCameraView() {
    final isReady = _controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (isReady)
            ClipRRect(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),

          // Top UI gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom UI gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _CamButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _CamButton(
                    icon: _flashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () {
                      setState(() => _flashOn = !_flashOn);
                      _controller?.setFlashMode(
                        _flashOn ? FlashMode.torch : FlashMode.off,
                      );
                    },
                    active: _flashOn,
                  ),
                  const SizedBox(width: 10),
                  _CamButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: () async {
                      setState(() => _frontCamera = !_frontCamera);
                      await _setupCamera(_frontCamera ? 1 : 0);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Viewfinder corners
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),

          // Center label
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Text(
                  'Point at trash to report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gallery (placeholder)
                    _CamButton(
                      icon: Icons.photo_library_rounded,
                      size: 48,
                      onTap: () {},
                    ),

                    // Shutter
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: _state == UploadState.capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Zoom toggle
                    _CamButton(
                      icon: Icons.zoom_in_rounded,
                      size: 48,
                      onTap: () async {
                        final next = _zoomLevel == 1.0 ? 2.0 : 1.0;
                        setState(() => _zoomLevel = next);
                        await _controller?.setZoomLevel(next);
                      },
                      label: '${_zoomLevel.toInt()}x',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preview Sheet ─────────────────────────────────────────────────────────────

class _PreviewSheet extends StatefulWidget {
  final File image;
  final VoidCallback onConfirm; // ✅ no intensity in callback
  final VoidCallback onRetake;

  const _PreviewSheet({
    required this.image,
    required this.onConfirm,
    required this.onRetake,
  });

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  // ✅ remove _intensity field

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.navBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Image.file(
              widget.image,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),

          // ✅ Intensity selector completely removed
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onRetake,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Retake',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.onConfirm, // ✅ no intensity
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Submit Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ─── Uploading Screen ──────────────────────────────────────────────────────────

class _UploadingScreen extends StatelessWidget {
  const _UploadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryLight,
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Uploading your report...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Getting your location & saving',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Result Screen ─────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final bool success;
  final String? errorMsg;
  final VoidCallback onDone;

  const _ResultScreen({
    required this.success,
    this.errorMsg,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: success
                      ? AppTheme.primaryLight
                      : AppTheme.error.withOpacity(0.1),
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  size: 48,
                  color: success ? AppTheme.primary : AppTheme.error,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                success ? 'Report Submitted!' : 'Submission Failed',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                success
                    ? 'Your report has been saved.\nThank you for keeping your community clean! 🌿'
                    : (errorMsg != null
                          ? 'Something went wrong.\nPlease try again.'
                          : 'Unexpected error. Please retry.'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success
                        ? AppTheme.primary
                        : AppTheme.bgCard,
                    foregroundColor: success
                        ? Colors.white
                        : AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      side: success
                          ? BorderSide.none
                          : BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    success ? 'Back to Home' : 'Try Again',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (success) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/track'),
                  child: Text(
                    'View My Reports',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

class _CamButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;
  final String? label;

  const _CamButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 42,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppTheme.primary.withOpacity(0.9)
              : Colors.black.withOpacity(0.45),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              )
            : Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

class _IntensityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IntensityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    const r = 8.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
        ..lineTo(size.width, len),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
        ..lineTo(len, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..arcToPoint(
          Offset(size.width, size.height - r),
          radius: const Radius.circular(r),
        )
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
