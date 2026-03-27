// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/map_screen.dart';
import 'screens/track_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/name_address_screen.dart';
// import 'screens/heatmap_screen.dart'; // Uncomment if needed
import 'services/notification_service.dart';

// ── Global Supabase client shorthand
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── 1. Load .env
  await dotenv.load(fileName: '.env');

  // ── 2. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── 3. Initialize Supabase (Must happen before notifications try to sync tokens)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // ── 4. Initialize Notifications
  await NotificationService.initialize();

  // ── 5. Mapbox
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_TOKEN']!);

  runApp(const BinApp());
}

class BinApp extends StatelessWidget {
  const BinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BIN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,

      // ── Auto-login with Firebase
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<bool>(
              future: checkUserExists(snapshot.data!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  );
                }
                if (snap.data == true) {
                  return const HomeScreen();
                } else {
                  return const LoginScreen();
                }
              },
            );
          }

          return const LoginScreen();
        },
      ),

      // ── Named routes with transitions
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/otp':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => OTPScreen(
                phone: args['phone'],
                verificationId: args['verificationId'],
                isLogin: args['isLogin'] ?? false,
              ),
            );
          case '/name_address':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => NameAddressScreen(phone: args['phone']),
            );
          case '/home':
            return _slideUp(const HomeScreen());
          case '/camera':
            return _slideUp(const CameraScreen());
          case '/map':
            return _fade(const MapScreen());
          case '/track':
            return _slideRight(const TrackScreen());
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }

  // ── Check if Firebase user exists in Supabase profiles table
  Future<bool> checkUserExists(User user) async {
    try {
      final lookup = user.email ?? user.phoneNumber;
      if (lookup == null) return false;

      final field = user.email != null ? 'email' : 'phone';

      final data = await supabase
          .from('profiles')
          .select('id')
          .eq(field, lookup)
          .maybeSingle();

      if (data != null) {
        // ✅ User is validated. Sync their FCM token to Supabase immediately.
        await NotificationService.syncFCMToken();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Route transition helpers
  PageRouteBuilder _slideUp(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, _) => page,
    transitionsBuilder: (_, a, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  PageRouteBuilder _slideRight(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, _) => page,
    transitionsBuilder: (_, a, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, _) => page,
    transitionsBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}
