import 'package:flutter/material.dart';
import 'package:secureher/theme/app_theme.dart';
import 'package:secureher/screens/login_screen.dart';
import 'package:secureher/screens/main_screen.dart';
import 'package:secureher/screens/register_screen.dart';
import 'package:secureher/screens/onboarding_screen.dart';
import 'package:secureher/screens/location_sharing_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secureher/services/emergency_contact_service.dart';
import 'package:secureher/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(ThemeMode.system);
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = !_isDarkMode;
    _themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'SecureHer',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return MaterialPageRoute(builder: (_) => AuthWrapper(onThemeToggle: _toggleTheme));
            } else if (settings.name == '/main') {
              return MaterialPageRoute(builder: (_) => MainScreen(onThemeToggle: _toggleTheme));
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
                  builder: (_) => AuthWrapper(onThemeToggle: _toggleTheme),
                  settings: RouteSettings(
                    name: '/',
                    arguments: {'sharingCode': sharingCode},
                  ),
                ),
              ];
            }
            return [
              MaterialPageRoute(
                builder: (_) => AuthWrapper(onThemeToggle: _toggleTheme),
                settings: const RouteSettings(name: '/'),
              ),
            ];
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final VoidCallback onThemeToggle;

  const AuthWrapper({super.key, required this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return MainScreen(onThemeToggle: onThemeToggle);
        }

        return const LoginScreen();
      },
    );
  }
}
