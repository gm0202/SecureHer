import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secureher/screens/login_screen.dart';
import 'package:secureher/screens/register_screen.dart';
import 'package:secureher/screens/main_screen.dart';
import 'package:secureher/screens/onboarding_screen.dart';
import 'package:secureher/services/emergency_contact_service.dart';

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
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

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
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => MainScreen(onThemeToggle: _toggleTheme),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          // User is authenticated, check onboarding status
          return FutureBuilder<bool>(
            future: EmergencyContactService().isOnboardingCompleted(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (onboardingSnapshot.hasData && onboardingSnapshot.data == true) {
                // User is authenticated and has completed onboarding
                return MainScreen(
                  onThemeToggle: () {
                    final appState = context.findAncestorStateOfType<_MyAppState>();
                    if (appState != null) {
                      appState._toggleTheme();
                    }
                  },
                );
              } else {
                // User is authenticated but hasn't completed onboarding
                return const OnboardingScreen();
              }
            },
          );
        }

        // User is not authenticated, show login screen
        return const LoginScreen();
      },
    );
  }
}
