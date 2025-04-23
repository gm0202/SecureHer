import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../services/emergency_contact_service.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({Key? key}) : super(key: key);

  @override
  _SOSButtonState createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  final EmergencyContactService _contactService = EmergencyContactService();
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

Please help me!

📍 Location: https://www.google.com/maps?q=${position.latitude},${position.longitude}''';
      }

      return '''
🚨 SOS ALERT 🚨

I need immediate help!

📍 My current location:
Latitude: ${position.latitude}
Longitude: ${position.longitude}

Please help me!

📍 Location: https://www.google.com/maps?q=${position.latitude},${position.longitude}''';
    } catch (e) {
      print('Error getting location: $e');
      return '''
🚨 SOS ALERT 🚨

I need immediate help!

📍 Location tracking failed. Please try again.

Please help me!''';
    }
  }

  Future<void> _openWhatsApp(String phone, String message) async {
    final url = Uri.parse(_contactService.getWhatsAppUrl(phone, message));
    
    print('Attempting to open WhatsApp with URL: ${url.toString()}');
    
    if (await canLaunchUrl(url)) {
      print('Launching WhatsApp...');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch WhatsApp');
      throw 'Could not launch WhatsApp';
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
      await _openWhatsApp(phone, message);
    } catch (e) {
      print('Error handling SOS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Please make sure it is installed.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 56,
        minHeight: 56,
        maxWidth: 100,
        maxHeight: 100,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleSOS,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
} 