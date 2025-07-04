import 'package:flutter/material.dart';
import 'package:secureher/theme/app_theme.dart';
import 'package:secureher/widgets/animated_feature_card.dart';
import 'package:secureher/widgets/hidden_camera_detector.dart';
import 'package:secureher/screens/safety_tips_screen.dart';
import 'package:secureher/screens/self_defense_screen.dart';
import 'package:secureher/screens/contacts_screen.dart';
import 'package:secureher/screens/live_tracking_screen.dart';
import 'package:secureher/screens/camera_detector_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSOSActive = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleSOS() async {
    if (!_isSOSActive) {
      setState(() {
        _isSOSActive = true;
      });

      // Play siren sound
      await _audioPlayer.play(AssetSource('policesiren.mp3'));

      // Get current location
      Position position = await Geolocator.getCurrentPosition();
      String locationMessage = '''🚨 SOS ALERT 🚨

I need immediate help!

📍 My current location:
Latitude: ${position.latitude}
Longitude: ${position.longitude}

Please help me!

📍 Location: https://www.google.com/maps?q=${position.latitude},${position.longitude}''';

      // Share via WhatsApp
      await Share.share(
        locationMessage,
        subject: 'Emergency SOS Alert',
      );
    } else {
    setState(() {
        _isSOSActive = false;
    });
      await _audioPlayer.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('SecureHer'),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: widget.toggleTheme,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSOS,
        backgroundColor: _isSOSActive ? Colors.green : AppTheme.accentColor,
        child: const Icon(Icons.emergency, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to SecureHer',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your personal safety companion',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Quick Action Cards',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildQuickActionCard(
                        context,
                        'SOS Alert',
                        'Quick emergency alert',
                        Icons.emergency,
                        const Color(0xFFFF6B6B),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(
                        context,
                        'Live Tracking',
                        'Share your location',
                        Icons.location_on,
                        const Color(0xFF6C63FF),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveTrackingScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(
                        context,
                        'Camera Detector',
                        'Find hidden cameras',
                        Icons.camera_alt,
                        const Color(0xFF00D1FF),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraDetectorScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Safety Tools',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    AnimatedFeatureCard(
                      title: 'Emergency Contacts',
                      description: 'Quick access to trusted contacts',
                      icon: Icons.contacts,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContactsScreen(),
                          ),
                        );
                      },
                      gradientStart: const Color(0xFF6C63FF),
                      gradientEnd: const Color(0xFF9C63FF),
                    ),
                    AnimatedFeatureCard(
                      title: 'Safety Tips',
                      description: 'Learn safety guidelines',
                      icon: Icons.security,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SafetyTipsScreen(),
                          ),
                        );
                      },
                      gradientStart: const Color(0xFF00D1FF),
                      gradientEnd: const Color(0xFF00FFD1),
                    ),
                    AnimatedFeatureCard(
                      title: 'Self Defense',
                      description: 'Basic self defense techniques',
                      icon: Icons.sports_martial_arts,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelfDefenseScreen(),
                          ),
                        );
                      },
                      gradientStart: const Color(0xFFFF6B6B),
                      gradientEnd: const Color(0xFFFF8E8E),
                    ),
                    AnimatedFeatureCard(
                      title: 'Emergency Services',
                      description: 'Quick dial emergency numbers',
                      icon: Icons.local_police,
                      onTap: () {
                        _showEmergencyServicesDialog(context);
                      },
                      gradientStart: const Color(0xFF00FFD1),
                      gradientEnd: const Color(0xFF00D1FF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Emergency Services',
          style: TextStyle(color: Colors.white),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmergencyServiceButton(
                  context,
                  'Police',
                  '100',
                  Icons.local_police,
                  const Color(0xFF6C63FF),
                ),
                const SizedBox(height: 6),
                _buildEmergencyServiceButton(
                  context,
                  'Ambulance',
                  '108',
                  Icons.local_hospital,
                  const Color(0xFFFF6B6B),
                ),
                const SizedBox(height: 6),
                _buildEmergencyServiceButton(
                  context,
                  'Fire Brigade',
                  '101',
                  Icons.fire_truck,
                  const Color(0xFFFF6B6B),
                ),
                const SizedBox(height: 6),
                _buildEmergencyServiceButton(
                  context,
                  'Emergency Response',
                  '112',
                  Icons.emergency,
                  const Color(0xFF00D1FF),
                ),
                const SizedBox(height: 6),
                _buildEmergencyServiceButton(
                  context,
                  'Women Help Line',
                  '1091',
                  Icons.support,
                  const Color(0xFF6C63FF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyServiceButton(
    BuildContext context,
    String title,
    String number,
    IconData icon,
    Color color,
  ) {
    return ElevatedButton(
      onPressed: () async {
        Navigator.pop(context);
        try {
          await FlutterPhoneDirectCaller.callNumber(number);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not make call: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '$title ($number)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 