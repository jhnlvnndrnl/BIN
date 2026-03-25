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

class _NameAddressScreenState extends State<NameAddressScreen> {
  final _nameController = TextEditingController();

  bool _termsAccepted = false;
  bool _isLocating = false;
  bool _isLoading = false;

  // ── Location data ──────────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String? _street;
  String? _barangay;
  String? _locationDisplay; // shown to user after GPS fetch

  static const _green = Color(0xFF4CAF50);

  static String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Request GPS and reverse geocode ───────────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);

    try {
      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          'Location permission permanently denied. Please enable it in settings.',
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied.');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Reverse geocode
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _street = place.street ?? '';
        // subLocality is typically the barangay in PH
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

  // ── Submit profile ─────────────────────────────────────────────────────────
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _editableStyle() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _green, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final locationFetched = _latitude != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                  const Spacer(flex: 2),

                  // ── Title ──────────────────────────────────────────────
                  const Center(
                    child: Text(
                      'Enter your personal\ninformation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                        height: 1.25,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Name ───────────────────────────────────────────────
                  _label('Name'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14),
                    decoration: _editableStyle(),
                  ),

                  const SizedBox(height: 24),

                  // ── Location Button ────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _fetchLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: locationFetched
                            ? _green
                            : const Color(0xFFDDDDDD),
                        width: locationFetched ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _green,
                            ),
                          )
                        : Icon(
                            locationFetched
                                ? Icons.location_on
                                : Icons.location_on_outlined,
                            color: locationFetched
                                ? _green
                                : const Color(0xFFAAAAAA),
                            size: 20,
                          ),
                    label: Text(
                      _isLocating
                          ? 'Getting location...'
                          : locationFetched
                          ? _locationDisplay ?? 'Location fetched'
                          : 'Allow location access',
                      style: TextStyle(
                        fontSize: 13,
                        color: locationFetched
                            ? const Color(0xFF111111)
                            : const Color(0xFFAAAAAA),
                        fontWeight: locationFetched
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Terms & Conditions Checkbox ────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: (val) =>
                              setState(() => _termsAccepted = val ?? false),
                          activeColor: _green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showTermsDialog,
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
                              children: [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // ── Create Account Button ──────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // ── Edit mobile number ─────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Center(
                      child: Text(
                        'edit mobile number',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
