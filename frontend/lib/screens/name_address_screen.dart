import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class NameAddressScreen extends StatefulWidget {
  final String? phone;
  final String? email;

  const NameAddressScreen({super.key, this.phone, this.email});

  @override
  State<NameAddressScreen> createState() => _NameAddressScreenState();
}

class _NameAddressScreenState extends State<NameAddressScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();

  bool _termsAccepted = false;
  bool _isLocating = false;
  bool _isLoading = false;

  double? _latitude;
  double? _longitude;
  String? _street;
  String? _barangay;
  String? _locationDisplay;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _green = Color(0xFF4CAF50);
  static const _greenLight = Color(0xFFE8F5E9);
  static const _greenDark = Color(0xFF388E3C);

  static String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          'Location permission permanently denied. Enable it in settings.',
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _street = place.street ?? '';
        _barangay = place.subLocality ?? place.locality ?? 'San Francisco';
        _locationDisplay =
            '${_street ?? ''}, ${_barangay ?? ''}, San Pablo City';
      } else {
        _locationDisplay = 'Location fetched (no address found)';
      }

      setState(() {});
    } catch (e) {
      _showSnackBar('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }
    if (!_termsAccepted) {
      _showSnackBar('Please accept the terms and conditions');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _showSnackBar('Please allow location access first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        _showSnackBar('Not authenticated. Please sign in again.');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': name,
          'email': widget.email,
          'phone': widget.phone,
          'street': _street ?? '',
          'barangay': _barangay ?? 'San Francisco',
          'city': 'San Pablo City',
          'latitude': _latitude,
          'longitude': _longitude,
          'role': 'resident',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        String errorMessage = 'Error saving profile (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          errorMessage = body['detail'] ?? errorMessage;
        } catch (_) {}
        _showSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'By using BIN, you agree to allow the app to collect your name, '
            'contact information, and GPS location solely for the purpose of '
            'waste collection services in San Pablo City. Your data will not '
            'be shared with third parties without your consent.\n\n'
            'Location data is used to identify your household for accurate '
            'waste collection scheduling and routing.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationFetched = _latitude != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // ── Header Card ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _greenLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: _green,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            "Almost there —\nlet's set up your profile",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          const Text(
                            'We need a few details to connect you\nwith your local waste collection service.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Form Card ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Name Field ───────────────────────────────────
                          _SectionLabel(label: 'Full Name'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111111),
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Juan dela Cruz',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCCCCCC),
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                size: 20,
                                color: Color(0xFFAAAAAA),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEEEEEE),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _green,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Location Field ───────────────────────────────
                          _SectionLabel(label: 'Your Location'),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _isLocating ? null : _fetchLocation,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: locationFetched
                                    ? _greenLight
                                    : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: locationFetched
                                      ? _green
                                      : const Color(0xFFEEEEEE),
                                  width: locationFetched ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isLocating
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _green,
                                            ),
                                          )
                                        : Icon(
                                            key: ValueKey(locationFetched),
                                            locationFetched
                                                ? Icons.location_on_rounded
                                                : Icons.location_on_outlined,
                                            size: 20,
                                            color: locationFetched
                                                ? _greenDark
                                                : const Color(0xFFAAAAAA),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _isLocating
                                          ? 'Fetching your location...'
                                          : locationFetched
                                          ? _locationDisplay ?? 'Location saved'
                                          : 'Tap to allow location access',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: locationFetched
                                            ? _greenDark
                                            : const Color(0xFFAAAAAA),
                                        fontWeight: locationFetched
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (locationFetched)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: _green,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Terms ────────────────────────────────────────
                          GestureDetector(
                            onTap: () => setState(
                              () => _termsAccepted = !_termsAccepted,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _termsAccepted
                                    ? _greenLight
                                    : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _termsAccepted
                                      ? _green
                                      : const Color(0xFFEEEEEE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _termsAccepted
                                          ? _green
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _termsAccepted
                                            ? _green
                                            : const Color(0xFFDDDDDD),
                                      ),
                                    ),
                                    child: _termsAccepted
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF666666),
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'I agree to the ',
                                          ),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: _showTermsDialog,
                                              child: const Text(
                                                'Terms and Conditions',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _green,
                                                  fontWeight: FontWeight.w600,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Progress dots ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepDot(active: false),
                        const SizedBox(width: 6),
                        _StepDot(active: true),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Create Account Button ──────────────────────────────
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),

                    // ── Back link ──────────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Center(
                        child: Text(
                          '← edit mobile number',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  const _StepDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4CAF50) : const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
