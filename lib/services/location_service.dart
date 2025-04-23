import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _locationSubscription;
  bool _isSharing = false;

  String get _userId => _auth.currentUser?.uid ?? '';

  Future<void> startSharingLocation() async {
    if (_isSharing) return;

    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isSharing = true;

    // Start location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      try {
        // Update location in Firestore
        await _firestore.collection('users').doc(_userId).set({
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          },
          'isSharingLocation': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        print('Location updated: ${position.latitude}, ${position.longitude}'); // Debug log
      } catch (e) {
        print('Error updating location: $e'); // Debug log
      }
    });
  }

  Future<void> stopSharingLocation() async {
    if (!_isSharing) return;

    _locationSubscription?.cancel();
    _isSharing = false;

    // Update Firestore to indicate location sharing is stopped
    await _firestore.collection('users').doc(_userId).update({
      'isSharingLocation': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<String> generateShareableLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Generate a unique sharing code
    final sharingCode = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Save sharing code to Firestore
    await _firestore.collection('location_sharing').doc(sharingCode).set({
      'sharing_code': sharingCode,
      'user_id': user.uid,
      'user_name': user.displayName ?? 'User',
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': FieldValue.serverTimestamp(), // Add expiration if needed
    });
    
    // Create the sharing link
    return 'https://livetrackingofuser.vercel.app/?code=$sharingCode';
  }

  Future<void> handleDeepLink(Uri uri) async {
    if (uri.scheme == 'https' && 
        uri.host == 'secureher.page.link' && 
        uri.path == '/tracking') {
      // Get the sharing code from the query parameters
      final sharingCode = uri.queryParameters['code'];
      if (sharingCode != null) {
        await _handleSharingCode(sharingCode);
      }
    }
  }

  Future<void> _handleSharingCode(String sharingCode) async {
    try {
      final doc = await _firestore
          .collection('location_sharing')
          .where('sharing_code', isEqualTo: sharingCode)
          .get();

      if (doc.docs.isEmpty) {
        throw Exception('Invalid sharing code');
      }

      final data = doc.docs.first.data();
      final userId = data['user_id'] as String;

      // Store the tracking relationship
      await _firestore.collection('tracking_relationships').add({
        'tracker_id': FirebaseAuth.instance.currentUser!.uid,
        'tracked_id': userId,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Start tracking the user
      await startTrackingUser(userId);
    } catch (e) {
      print('Error handling sharing code: $e');
      rethrow;
    }
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot> getLocationStream(String sharingCode) {
    return _firestore
        .collection('location_shares')
        .doc(sharingCode)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getSharedLocation(String sharingCode) async {
    final shareDoc = await _firestore
        .collection('location_shares')
        .doc(sharingCode)
        .get();

    if (!shareDoc.exists || !(shareDoc.data()?['isActive'] ?? false)) {
      return null;
    }

    final userId = shareDoc.data()?['userId'];
    final userDoc = await _firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) return null;

    return userDoc.data()?['location'];
  }

  Future<void> startTrackingUser(String userId) async {
    // Subscribe to the tracked user's location updates
    _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['isSharingLocation'] == true) {
          final location = data['location'];
          if (location != null) {
            // Handle the location update
            // You can emit this to a stream or update UI
          }
        }
      }
    });
  }

  void dispose() {
    _locationSubscription?.cancel();
  }
} 