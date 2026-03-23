import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

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

  // ✅ Email Login
  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithPassword(email: email, password: password);

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Google Login (Supabase)
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.yourapp://login-callback/',
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Google sign-in failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
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
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              const Center(
                child: Text(
                  'BIN',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFFCCCCCC),
                    letterSpacing: 6,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              const Text(
                'email',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputStyle(),
              ),

              const SizedBox(height: 16),

              const Text(
                'password',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputStyle().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'or',
                  style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Google Button
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                child: const Text('Login with Google'),
              ),

              const Spacer(flex: 2),

              // ✅ Email Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: const Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
