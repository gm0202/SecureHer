import 'dart:math';
import 'package:flutter/material.dart';
import 'package:secureher/widgets/home_widgets/custom_carousel.dart';
import 'package:secureher/widgets/home_widgets/emergency.dart';
import 'package:secureher/widgets/Live_safe.dart';
import 'package:secureher/widgets/home_widgets/Safe_home/safehome.dart';
import 'package:secureher/widgets/map_widget.dart';
import 'package:secureher/widgets/home_widgets/custom_appbar.dart';
import 'package:secureher/utils/quotes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secureher/screens/contacts_screen.dart';
import 'package:secureher/screens/settings_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secureher/services/emergency_contact_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:secureher/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int qIndex = 2;
  final _auth = FirebaseAuth.instance;
  final _emergencyContactService = EmergencyContactService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _emergencyKey = GlobalKey();
  final GlobalKey _exploreKey = GlobalKey();
  final GlobalKey _crimeAnalysisKey = GlobalKey();
  final GlobalKey _sosKey = GlobalKey();
  bool _isLoading = false;

  Future<void> _sendSOS() async {
    setState(() => _isLoading = true);
    try {
      // Check if user is logged in
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please log in to use SOS feature');
      }

      // Get primary contact number
      final phoneNumber = await _emergencyContactService.getPrimaryContactNumber();
      if (phoneNumber == null) {
        throw Exception('No emergency contact found. Please set up an emergency contact in the app.');
      }

      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services to use SOS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please enable location permissions to use SOS.');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];
      String address = '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';

      // Remove any non-numeric characters from the phone number and ensure it starts with country code
      String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      if (!cleanPhoneNumber.startsWith('+')) {
        cleanPhoneNumber = '+91$cleanPhoneNumber'; // Assuming Indian number if no country code
      }

      // Format message
      String message = '🚨 SOS ALERT 🚨\n\n'
          'I need immediate help!\n\n'
          '📍 My current location:\n'
          'Latitude: ${position.latitude}\n'
          'Longitude: ${position.longitude}\n'
          'Address: $address\n\n'
          'Please help me!';

      // Create Google Maps link
      String mapsLink = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      
      // Combine message with maps link
      String fullMessage = '$message\n\n📍 Location: $mapsLink';

      // Try WhatsApp first
      String whatsappUrl = 'whatsapp://send?phone=$cleanPhoneNumber&text=${Uri.encodeComponent(fullMessage)}';
      
      try {
        if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
          await launchUrl(
            Uri.parse(whatsappUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          // If WhatsApp fails, try SMS
          String smsUrl = 'sms:$cleanPhoneNumber?body=${Uri.encodeComponent(fullMessage)}';
          if (await canLaunchUrl(Uri.parse(smsUrl))) {
            await launchUrl(
              Uri.parse(smsUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            // If both fail, try opening WhatsApp in browser
            String webWhatsappUrl = 'https://web.whatsapp.com/send?phone=$cleanPhoneNumber&text=${Uri.encodeComponent(fullMessage)}';
            if (await canLaunchUrl(Uri.parse(webWhatsappUrl))) {
              await launchUrl(
                Uri.parse(webWhatsappUrl),
                mode: LaunchMode.externalApplication,
              );
            } else {
              throw Exception('Could not send SOS message. Please make sure you have WhatsApp installed and try again.');
            }
          }
        }
      } catch (e) {
        print('Error launching messaging app: $e');
        throw Exception('Could not send SOS message. Please make sure you have WhatsApp installed and try again.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void getRandomQuote() {
    Random random = Random();
    setState(() {
      qIndex = random.nextInt(sweetSayings.length);
    });
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SecureHer',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink.shade400,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.pink.shade400,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'SecureHer',
                      style: TextStyle(
                      color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your Safety, Our Priority',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency),
              title: const Text('Emergency'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_emergencyKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.explore),
              title: const Text('Explore'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_exploreKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Crime Analysis'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_crimeAnalysisKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sos),
              title: const Text('SOS'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_sosKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Emergency Contacts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                          context,
                  MaterialPageRoute(builder: (context) => const ContactsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
                  ],
                ),
              ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: getRandomQuote,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        sweetSayings[qIndex],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
              Container(
                    padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CustomCarousel(),
                    const SizedBox(height: 24),
                    Container(
                          key: _emergencyKey,
                          padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'Emergency',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const EmergencyWidget(),
                    const SizedBox(height: 24),
                    Container(
                          key: _exploreKey,
                          padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const LiveSafe(),
                        const SizedBox(height: 24),
                        Container(
                          key: _crimeAnalysisKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'Crime Analysis',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const MapWidget(),
                        const SizedBox(height: 24),
                        Container(
                          key: _sosKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SafeHome(),
                  ],
                ),
              ),
            ],
          ),
            ),
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: _isLoading ? null : _sendSOS,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/SOS.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.sos,
                            color: Colors.red,
                            size: 40,
                          );
                        },
                      ),
                      if (_isLoading)
                        const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
