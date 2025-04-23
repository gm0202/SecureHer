import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secureher/screens/login_screen.dart';
import 'package:secureher/screens/register_screen.dart';
import 'package:secureher/screens/main_screen.dart';
import 'package:secureher/screens/onboarding_screen.dart';
import 'package:secureher/screens/location_sharing_screen.dart';
import 'package:secureher/services/emergency_contact_service.dart';
import 'package:secureher/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureHer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const AuthWrapper());
        } else if (settings.name == '/main') {
          return MaterialPageRoute(builder: (_) => const MainScreen());
        } else if (settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        } else if (settings.name == '/register') {
          return MaterialPageRoute(builder: (_) => const RegisterScreen());
        } else if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (_) => const OnboardingScreen());
        } else if (settings.name == '/location-sharing') {
          return MaterialPageRoute(builder: (_) => const LocationSharingScreen());
        }
        return null;
      },
      onGenerateInitialRoutes: (initialRoute) {
        if (initialRoute.startsWith('secureher://track/')) {
          final sharingCode = initialRoute.split('/').last;
          return [
            MaterialPageRoute(
              builder: (_) => const AuthWrapper(),
              settings: RouteSettings(
                name: '/',
                arguments: {'sharingCode': sharingCode},
              ),
            ),
          ];
        }
        return [
          MaterialPageRoute(
            builder: (_) => const AuthWrapper(),
            settings: const RouteSettings(name: '/'),
          ),
        ];
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LocationService _locationService = LocationService();
  String? _sharingCode;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkInitialRoute();
  }

  void _checkInitialRoute() {
    final route = ModalRoute.of(context)?.settings.name;
    if (route != null && route.startsWith('secureher://track/')) {
      setState(() {
        _sharingCode = route.split('/').last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          if (_sharingCode != null) {
            _handleSharingCode();
          }
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }

  Future<void> _handleSharingCode() async {
    try {
      await _locationService.handleDeepLink(
        Uri.parse('secureher://track/$_sharingCode'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing started successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting location sharing: $e')),
      );
    }
  }
}
