import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  final LocationService _locationService = LocationService();
  bool _isSharing = false;
  String? _shareableLink;
  GoogleMapController? _mapController;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      setState(() {
        _currentLocation = location;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );
    }
  }

  Future<void> _toggleSharing() async {
    try {
      if (!_isSharing) {
        await _locationService.startSharingLocation();
        final link = await generateSharingLink();
        setState(() {
          _isSharing = true;
          _shareableLink = link;
        });
      } else {
        await _locationService.stopSharingLocation();
        setState(() {
          _isSharing = false;
          _shareableLink = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareLocation() async {
    if (_shareableLink != null) {
      await Share.share(
        'Track my live location: $_shareableLink',
        subject: 'My Live Location',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Sharing'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentLocation == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _currentLocation != null
                        ? {
                            Marker(
                              markerId: const MarkerId('currentLocation'),
                              position: _currentLocation!,
                            ),
                          }
                        : {},
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _toggleSharing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSharing ? Colors.red : Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    _isSharing ? 'Stop Sharing' : 'Start Sharing',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isSharing && _shareableLink != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _shareLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Share Location Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

Future<String> generateSharingLink() async {
  try {
    // Generate a unique sharing code
    final sharingCode = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    // Save sharing code to Firestore
    await FirebaseFirestore.instance
        .collection('location_sharing')
        .doc(sharingCode)
        .set({
          'sharing_code': sharingCode,
          'user_id': user.uid,
          'user_name': user.displayName ?? 'User',
          'created_at': FieldValue.serverTimestamp(),
          'expires_at': FieldValue.serverTimestamp(), // Add expiration if needed
        });
    
    // Create the sharing link
    final sharingLink = 'https://livetrackingofuser.vercel.app/?code=$sharingCode';
    
    return sharingLink;
  } catch (e) {
    print('Error generating sharing link: $e');
    rethrow;
  }
} 