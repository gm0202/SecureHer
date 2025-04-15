import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:toastification/toastification.dart';
import 'package:share_plus/share_plus.dart';

class SafeHome extends StatefulWidget {
  const SafeHome({super.key});

  @override
  State<SafeHome> createState() => _SafeHomeState();
}

class _SafeHomeState extends State<SafeHome> {
  String? _currentAddress;
  Position? _currentPosition;

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
    locationMessage +=
        "https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude}%2C${_currentPosition!.longitude}\n\n";
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
    return InkWell(
      onTap: () => showModelSafeHome(context),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          height: 180,
          width: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade400, Colors.pink.shade300],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "SOS Button",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Share your location in emergency",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/route.jpg', fit: BoxFit.cover),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String title;
  final Function onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.5,
      child: ElevatedButton(
        onPressed: () => onPressed(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
