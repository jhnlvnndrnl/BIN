import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  static const Color _green = Color(0xFF4CAF50);

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verifyOtp(String verificationId) async {
    final code = _otpCode;

    if (code.length < 6) {
      _showSnackBar('Please enter the complete 6-digit code');
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
        if (mounted) {
          _showSnackBar('Welcome back!');
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (checkResponse.statusCode == 404) {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Title
              const Text(
                "We've sent you a 6-digit\nverification code at",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFBBBBBB),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // Phone number
              Text(
                phone,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                ),
              ),

              const SizedBox(height: 32),

              // 6 OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _green, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => _onChanged(value, index),
                    ),
                  );
                }),
              ),

              const Spacer(flex: 3),

              // Continue button
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
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Center(
                  child: Text(
                    'Already has account?',
                    style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}