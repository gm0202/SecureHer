import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:secureher/firebase_options.dart';
import 'package:secureher/home_screen.dart';
import 'package:secureher/screens/contacts_screen.dart';
import 'package:secureher/widgets/bottom_navigation.dart';
import 'package:secureher/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
