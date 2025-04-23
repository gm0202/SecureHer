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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secureher/screens/login_screen.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback? onThemeToggle;
  
  const MainScreen({
    super.key,
    this.onThemeToggle,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSOSActive = false;
  bool _isLoading = false;
  int _selectedIndex = 0;
  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      
      // Generate Google Maps URL
      String mapsUrl = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      
      // Generate live tracking URL with timestamp as code
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String liveTrackingUrl = 'https://livetrackingofuser.vercel.app/?code=$timestamp';

      String locationMessage = '''🚨 SOS ALERT 🚨

I need immediate help!

📍 My current location:
Latitude: ${position.latitude}
Longitude: ${position.longitude}

📍 Static Location: $mapsUrl
📍 Live Tracking: $liveTrackingUrl

Please help me!''';

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
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from going back to login screen
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('SecureHer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: () {
                Navigator.pushNamed(context, '/location-sharing');
              },
            ),
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              onPressed: widget.onThemeToggle,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
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
                          _handleLogout();
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _handleSOS,
          backgroundColor: _isSOSActive ? Colors.green : AppTheme.accentColor,
          child: const Icon(Icons.emergency, color: Colors.white),
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                      height: 160,
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
                          const SizedBox(width: 12),
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
                          const SizedBox(width: 12),
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
                    const SizedBox(height: 24),
                    Text(
                      'Safety Tools',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: [
                        AnimatedFeatureCard(
                          title: 'Contacts',
                          description: 'Trusted contacts',
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
                          title: 'Tips',
                          description: 'Safety guidelines',
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
                          title: 'Defense',
                          description: 'Self defense',
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
                          title: 'Emergency',
                          description: 'Quick dial',
                          icon: Icons.local_police,
                          onTap: () {
                            _showEmergencyServicesDialog(context);
                          },
                          gradientStart: const Color(0xFF00FFD1),
                          gradientEnd: const Color(0xFF00D1FF),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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