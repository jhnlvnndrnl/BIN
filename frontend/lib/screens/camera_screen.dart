// lib/screens/camera_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';
import 'package:uuid/uuid.dart';
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

  // Holds EXIF-extracted GPS from gallery image (null = use live GPS)
  double? _exifLat;
  double? _exifLng;

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

  // ─── Camera Capture ────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_state != UploadState.idle) return;

    HapticFeedback.heavyImpact();
    setState(() => _state = UploadState.capturing);

    try {
      final xfile = await _controller!.takePicture();
      setState(() {
        _capturedFile = File(xfile.path);
        _exifLat = null; // camera shot → use live GPS
        _exifLng = null;
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

  // ─── Gallery Picker ────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final file = File(picked.path);

    // Attempt to read EXIF GPS data (native_exif ^0.7.0 API)
    double? lat;
    double? lng;
    try {
      final exif = await Exif.fromPath(picked.path);
      final latLong = await exif.getLatLong();
      await exif.close();
      if (latLong != null) {
        lat = latLong.latitude;
        lng = latLong.longitude;
      }
    } catch (e) {
      debugPrint('[Gallery] EXIF read error: $e');
    }

    setState(() {
      _capturedFile = file;
      _exifLat = lat;
      _exifLng = lng;
    });

    _showPreviewSheet(fromGallery: true, hasExifLocation: lat != null);
  }

  // ─── Preview Sheet ─────────────────────────────────────────────────────────

  void _showPreviewSheet({
    bool fromGallery = false,
    bool hasExifLocation = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewSheet(
        image: _capturedFile!,
        fromGallery: fromGallery,
        hasExifLocation: hasExifLocation,
        onConfirm: _upload,
        onRetake: () {
          Navigator.pop(context);
          setState(() {
            _capturedFile = null;
            _exifLat = null;
            _exifLng = null;
          });
        },
      ),
    );
  }

  // ─── Upload ────────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_capturedFile == null) return;

    // ── Step 1: resolve location BEFORE closing the sheet ──────────────────
    // Requesting a system permission dialog while Navigator.pop is in-flight
    // suppresses the dialog silently on Android. Always resolve GPS first.
    double lat;
    double lng;

    if (_exifLat != null && _exifLng != null) {
      // Gallery image with embedded GPS — no permission needed
      lat = _exifLat!;
      lng = _exifLng!;
      debugPrint('[Camera] Using EXIF location: $lat, $lng');
    } else {
      // Camera shot or gallery image without EXIF → request live GPS
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to submit a report.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return; // sheet stays open — user can retry or retake
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permanently denied — enable it in Settings.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }

      // Permission granted — get position
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        debugPrint('[Camera] Using live GPS: $lat, $lng');
      } catch (e) {
        debugPrint('[Camera] GPS error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location. Try again outdoors.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    // ── Step 2: location resolved — now safe to close sheet & start upload ──
    if (mounted) Navigator.pop(context);
    setState(() => _state = UploadState.uploading);

    try {
      // (lat/lng already set above)

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
          debugPrint('[Camera] profile fetch error: $e');
        }
      }

      // Upload image to Supabase storage
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

      // Insert report with resolved coordinates
      await supabase.from('report_submission').insert({
        'image_link': imageLink,
        'lat': lat,
        'long': lng,
        'name': name,
        'user_id': userId,
      });

      setState(() => _state = UploadState.success);
    } catch (e) {
      debugPrint('[Camera] upload error: $e');
      setState(() {
        _state = UploadState.failure;
        _errorMsg = e.toString();
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

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
          _exifLat = null;
          _exifLng = null;
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
                    // ✅ Gallery button — now functional
                    _CamButton(
                      icon: Icons.photo_library_rounded,
                      size: 48,
                      onTap: _pickFromGallery,
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

class _PreviewSheet extends StatelessWidget {
  final File image;
  final bool fromGallery;
  final bool hasExifLocation;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  const _PreviewSheet({
    required this.image,
    required this.fromGallery,
    required this.hasExifLocation,
    required this.onConfirm,
    required this.onRetake,
  });

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
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Image.file(
              image,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Location source badge
          if (fromGallery)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: hasExifLocation
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: hasExifLocation
                      ? Colors.green.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasExifLocation
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
                    size: 14,
                    color: hasExifLocation ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasExifLocation
                        ? 'Location from photo metadata'
                        : 'No EXIF data — will use current GPS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasExifLocation ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    fromGallery ? 'Cancel' : 'Retake',
                    style: const TextStyle(
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
                  onPressed: onConfirm,
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
