import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  final String verificationId;
  final bool isLogin; // ← true = existing user, go to /home
  //   false = new user, go to /name_address

  const OTPScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    this.isLogin = false,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendSeconds = 60;
  Timer? _timer;
  String? _currentVerificationId;

  static const _green = Color(0xFF4CAF50);
  static const _grey = Color(0xFF888888);
  static const _lightGrey = Color(0xFFAAAAAA);
  static const _border = Color(0xFFDDDDDD);

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  String get _maskedPhone {
    if (widget.phone.length >= 4) {
      final visible = widget.phone.substring(widget.phone.length - 4);
      final masked = widget.phone.substring(0, widget.phone.length - 4);
      return masked.replaceAll(RegExp(r'\d'), 'x') + visible;
    }
    return widget.phone;
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otp.length != 6) {
      _showSnackBar('Please enter the complete 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!,
        smsCode: _otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      if (widget.isLogin) {
        // ── Existing user — go straight to home ───────────────────────────
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // ── New user — go to name/address to complete profile ─────────────
        Navigator.pushReplacementNamed(
          context,
          '/name_address',
          arguments: {'phone': widget.phone, 'email': null},
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'OTP verification failed');
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              widget.isLogin ? '/home' : '/name_address',
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnackBar(e.message ?? 'Failed to resend code');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _currentVerificationId = verificationId);
            _startCountdown();
            _showSnackBar('Code resent successfully');
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      _showSnackBar('Something went wrong');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBoxChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  void _onBoxKeyDown(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),

              const Text(
                'Verify your number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'We sent a 6 digit code to\n$_maskedPhone',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _grey, height: 1.5),
              ),

              const Spacer(flex: 2),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildOTPBox(i)),
              ),

              const SizedBox(height: 28),

              GestureDetector(
                onTap: _resendSeconds == 0 ? _resendCode : null,
                child: Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend code in ${_resendSeconds}s',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _lightGrey,
                          ),
                        )
                      : const Text(
                          'Resend code',
                          style: TextStyle(
                            fontSize: 13,
                            color: _green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),

              const Spacer(flex: 3),

              ElevatedButton(
                onPressed: (_isLoading || _otp.length != 6) ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _green.withOpacity(0.5),
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
                onTap: () => Navigator.pop(context),
                child: const Center(
                  child: Text(
                    'edit mobile number',
                    style: TextStyle(fontSize: 13, color: _lightGrey),
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

  Widget _buildOTPBox(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: 44,
      height: 52,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onBoxKeyDown(event, index),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFilled ? _green : _border,
                width: isFilled ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) => _onBoxChanged(value, index),
        ),
      ),
    );
  }
}
