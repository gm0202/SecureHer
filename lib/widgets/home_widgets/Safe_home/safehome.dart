import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:toastification/toastification.dart';
import 'package:share_plus/share_plus.dart';
import 'package:secureher/services/location_service.dart';

class SafeHome extends StatefulWidget {
  const SafeHome({super.key});

  @override
  State<SafeHome> createState() => _SafeHomeState();
}

class _SafeHomeState extends State<SafeHome> {
  String? _currentAddress;
  Position? _currentPosition;
  final LocationService _locationService = LocationService();
  bool _isSharing = false;
  String? _sharingLink;

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      toastification.show(
        context: context,
        title: const Text(
          'Location services are disabled. Please enable the services',
        ),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        toastification.show(
          context: context,
          title: const Text('Location permissions are denied'),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      toastification.show(
        context: context,
        title: const Text(
          'Location permissions are permanently denied, we cannot request permissions.',
        ),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
      await _getAddressFromLatLng(_currentPosition!);
    } catch (e) {
      toastification.show(
        context: context,
        title: const Text("Could not get current location"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks[0];
      setState(() {
        _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      });
    } catch (e) {
      toastification.show(
        context: context,
        title: const Text("Could not get address"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _startSharingLocation() async {
    try {
      await _locationService.startSharingLocation();
      final link = await _locationService.generateShareableLink();
      setState(() {
        _isSharing = true;
        _sharingLink = link;
      });
      toastification.show(
        context: context,
        title: const Text("Location sharing started"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } catch (e) {
      toastification.show(
        context: context,
        title: Text("Error starting location sharing: $e"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _stopSharingLocation() async {
    try {
      await _locationService.stopSharingLocation();
      setState(() {
        _isSharing = false;
        _sharingLink = null;
      });
      toastification.show(
        context: context,
        title: const Text("Location sharing stopped"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } catch (e) {
      toastification.show(
        context: context,
        title: Text("Error stopping location sharing: $e"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _shareLocation() {
    if (_currentPosition == null) {
      toastification.show(
        context: context,
        title: const Text("Location not available yet"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    String locationMessage = "My current location:\n";
    if (_isSharing && _sharingLink != null) {
      locationMessage += "📍 Live Location Tracking:\n$_sharingLink\n\n";
    }
    locationMessage +=
        "📍 Static Location:\nhttps://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude}%2C${_currentPosition!.longitude}\n\n";
    if (_currentAddress != null) {
      locationMessage += "Address: $_currentAddress";
    }

    Share.share(locationMessage);
  }

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  showModelSafeHome(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height / 1.4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Share Your Current Location",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                if (_currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _currentAddress ?? "Getting address...",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                SizedBox(height: 20),
                PrimaryButton(
                  title: "UPDATE LOCATION",
                  onPressed: () {
                    _getCurrentPosition();
                  },
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  title: _isSharing ? "STOP SHARING" : "START LIVE SHARING",
                  onPressed: () {
                    if (_isSharing) {
                      _stopSharingLocation();
                    } else {
                      _startSharingLocation();
                    }
                  },
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  title: "SHARE LOCATION",
                  onPressed: _shareLocation,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                "Safe Home",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home,
                  size: 50,
                  color: Colors.blue,
                ),
                SizedBox(height: 10),
                Text(
                  "Share your location with trusted contacts",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => showModelSafeHome(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Share Location",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const PrimaryButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
