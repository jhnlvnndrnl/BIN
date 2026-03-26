import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── PopScope blocks the Android back button from going back to auth ──────
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        // ── Temporary logout button in AppBar ──────────────────────────────
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // hides any back arrow
          actions: [
            TextButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(
                Icons.logout,
                size: 18,
                color: Color(0xFF888888),
              ),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const Center(
          child: Text(
            'Welcome to BIN!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Color(0xFFCCCCCC),
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
