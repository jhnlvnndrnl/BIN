import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _streetController = TextEditingController();
  bool _isLoading = false;

  static const _green = Color(0xFF4CAF50);

  // 🔧 Replace with your actual backend URL
  static const _baseUrl = 'https://your-backend-url.com';

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    final street = _streetController.text.trim();

    if (name.isEmpty || street.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get Firebase ID token (works for both SMS and Google users)
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
          'email': widget.email, // null for SMS users
          'phone': widget.phone, // null for Google users
          'street': street,
          'role': 'resident',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final body = jsonDecode(response.body);
        _showSnackBar(body['detail'] ?? 'Error saving profile');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Unexpected error: $e');
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

  InputDecoration _inputStyle({String? hintText, bool enabled = true}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _green),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : const Color(0xFFF9F9F9),
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

                  // ── Heading ───────────────────────────────────────────
                  const Center(
                    child: Text(
                      "We'd love to get to know you better!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Name ─────────────────────────────────────────────
                  _label('Name'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputStyle(),
                  ),

                  const SizedBox(height: 16),

                  // ── Province / City (locked) ──────────────────────────
                  _label('Province | City'),
                  TextField(
                    enabled: false,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputStyle(
                      hintText: 'San Pablo City',
                      enabled: false,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Barangay (locked) ─────────────────────────────────
                  _label('Barangay'),
                  TextField(
                    enabled: false,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputStyle(
                      hintText: 'San Francisco',
                      enabled: false,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Street ────────────────────────────────────────────
                  _label('Street'),
                  TextField(
                    controller: _streetController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputStyle(),
                  ),

                  const Spacer(flex: 2),

                  // ── Submit Button ─────────────────────────────────────
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

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
