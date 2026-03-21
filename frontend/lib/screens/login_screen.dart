import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // for the global supabase client

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const _green = Color(0xFF4CAF50);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email/Password Login ──────────────────────────────────────────
  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Navigate to home on success
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Login ──────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.yourapp://login-callback/',
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Google sign-in failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── SMS Login ─────────────────────────────────────────────────────
  Future<void> _signInWithSms() async {
    final phone = await _showPhoneDialog();
    if (phone == null || phone.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOtp(phone: phone);
      if (mounted) _showSnackBar('OTP sent to $phone');
      // TODO: navigate to OTP verification screen
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('SMS sign-in failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _showPhoneDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+639XXXXXXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // LOGO
              const Center(
                child: Text(
                  'LOGO',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFFCCCCCC),
                    letterSpacing: 6,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Email field
              const Text(
                'email',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Password field
              const Text(
                'password',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // OR divider
              const Center(
                child: Text(
                  'or',
                  style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                ),
              ),

              const SizedBox(height: 16),

              // Login with Google
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleIcon(),
                    const SizedBox(width: 10),
                    const Text(
                      'Login with Google',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Login with SMS
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithSms,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.sim_card_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Login with SMS',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Login button
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
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
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Create Account
              GestureDetector(
                onTap: () {
                  // TODO: navigate to register screen
                  Navigator.pushNamed(context, '/register');
                },
                child: const Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFAAAAAA),
                    ),
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

// ── Google Icon (unchanged) ───────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, bgPaint);
    final rect = Rect.fromCircle(center: center, radius: radius * 0.85);
    canvas.drawArc(rect, -2.4, 1.6, false,
        Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, -0.8, -1.6, false,
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, 0.8, 1.6, false,
        Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, 2.4, 0.8, false,
        Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(center.dx, center.dy), Offset(center.dx + radius * 0.85, center.dy),
        Paint()..color = const Color(0xFF4285F4)..strokeWidth = size.width * 0.18..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}