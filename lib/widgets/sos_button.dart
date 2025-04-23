import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import '../services/emergency_contact_service.dart';
import '../services/location_service.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({Key? key}) : super(key: key);

  @override
  _SOSButtonState createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  static const platform = MethodChannel('com.secureher.app/whatsapp');
  final EmergencyContactService _contactService = EmergencyContactService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;

  Future<String> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Location permission denied';
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Start sharing location
      await _locationService.startSharingLocation();
      final sharingLink = await _locationService.generateShareableLink();

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        return '''
🚨 SOS ALERT 🚨

I need immediate help!

📍 My current location:
Latitude: ${position.latitude}
Longitude: ${position.longitude}
Address: $address

📍 Live Location Tracking:
$sharingLink

Please help me!

📍 Static Location: https://www.google.com/maps?q=${position.latitude},${position.longitude}''';
      }

      return '''
🚨 SOS ALERT 🚨

I need immediate help!

📍 My current location:
Latitude: ${position.latitude}
Longitude: ${position.longitude}

📍 Live Location Tracking:
$sharingLink

Please help me!

📍 Static Location: https://www.google.com/maps?q=${position.latitude},${position.longitude}''';
    } catch (e) {
      print('Error getting location: $e');
      return '''
🚨 SOS ALERT 🚨

I need immediate help!

📍 Location tracking failed. Please try again.

Please help me!''';
    }
  }

  Future<void> _handleSOS() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final phone = await _contactService.getEmergencyContactPhone();
      if (phone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency contact found. Please add one first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final message = await _getCurrentLocation();
      
      // Call native method to open WhatsApp
      await platform.invokeMethod('openWhatsApp', {
        'phone': phone,
        'message': message,
      });
    } on PlatformException catch (e) {
      print("Error opening WhatsApp: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please make sure it is installed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error handling SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isLoading ? null : _handleSOS,
      backgroundColor: Colors.red,
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Icon(Icons.sos, color: Colors.white),
    );
  }
} 