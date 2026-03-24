import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  static const Color _green = Color(0xFF4CAF50);

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String verificationId) async {
    final code = _otpController.text.trim();

    if (code.isEmpty) {
      _showSnackBar('Please enter the OTP code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // STEP 1: Verify OTP with Firebase
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        _showSnackBar('Failed to get authentication token');
        return;
      }

      final backendUrl = dotenv.env['BACKEND_URL'];
      if (backendUrl == null) {
        _showSnackBar('Backend URL not configured');
        return;
      }

      // STEP 2: Check if profile already exists
      final checkResponse = await http.get(
        Uri.parse('$backendUrl/profile'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (checkResponse.statusCode == 200) {
        // Existing user — go to home
        if (mounted) {
          _showSnackBar('Welcome back!');
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (checkResponse.statusCode == 404) {
        // New user — create profile in Supabase via backend
        final createResponse = await http.post(
          Uri.parse('$backendUrl/profile'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: '{}',
        );

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          if (mounted) {
            _showSnackBar('Account created successfully!');
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          _showSnackBar('Failed to create profile: ${createResponse.body}');
        }
      } else {
        _showSnackBar('Server error: ${checkResponse.statusCode}');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Invalid OTP code');
    } catch (e) {
      _showSnackBar('Something went wrong');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final phone = args?['phone'] ?? '';
    final verificationId = args?['verificationId'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Verification',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a verification code to $phone',
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 48),
              const Text(
                'verification code',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: "",
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    _isLoading ? null : () => _verifyOtp(verificationId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
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
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}