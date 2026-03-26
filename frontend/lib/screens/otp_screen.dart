import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  final String verificationId;
  final bool isLogin;

  const OTPScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    this.isLogin = false,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendSeconds = 60;
  Timer? _timer;
  String? _currentVerificationId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _green = Color(0xFF4CAF50);
  static const _bg = Color(0xFFF4F8F4);

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startCountdown();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _fadeController.dispose();
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
      return masked.replaceAll(RegExp(r'\d'), '•') + visible;
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
        Navigator.pushReplacementNamed(context, '/home');
      } else {
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
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    if (_otp.length == 6) FocusScope.of(context).unfocus();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpFilled = _otp.length == 6;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // ── Header ────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.verified_outlined,
                              color: _green,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Check your messages',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We sent a 6-digit code to\n$_maskedPhone',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── OTP Card ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // OTP boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) => _buildOTPBox(i)),
                        ),

                        const SizedBox(height: 24),

                        // Resend
                        GestureDetector(
                          onTap: _resendSeconds == 0 ? _resendCode : null,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _resendSeconds > 0
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    key: const ValueKey('countdown'),
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: Color(0xFFBBBBBB),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resend in ${_resendSeconds}s',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFAAAAAA),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Resend code',
                                    key: ValueKey('resend'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Verify Button ─────────────────────────────────────
                  AnimatedOpacity(
                    opacity: otpFilled ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton(
                      onPressed: (_isLoading || !otpFilled) ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFilled ? _green : const Color(0xFFEEEEEE),
                width: isFilled ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
            filled: true,
            fillColor: isFilled
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFAFAFA),
          ),
          onChanged: (value) => _onBoxChanged(value, index),
        ),
      ),
    );
  }
}
