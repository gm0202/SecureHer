import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:secureher/theme/app_theme.dart';
import 'package:secureher/services/location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  final LocationService _locationService = LocationService();
  String? _sharingLink;
  Set<Marker> _markers = {};
  static const String _apiKey = 'AIzaSyA0kHChkc5NHL0Eoh4JzBKR6KyepOUWRGU';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  Future<void> _findNearbyPlaces(String type) async {
    if (_currentPosition == null) return;

    try {
      setState(() {
        _isLoading = true;
        _markers.clear();
      });

      // First try with a smaller radius (500m)
      final initialUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=500'
        '&type=$type'
        '&key=$_apiKey',
      );

      final initialResponse = await http.get(initialUrl);
      if (initialResponse.statusCode == 200) {
        final data = json.decode(initialResponse.body);
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          _updateMarkers(results);
          return;
        }

        // If no results in 500m, try 1km
        final secondUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=1000'
          '&type=$type'
          '&key=$_apiKey',
        );

        final secondResponse = await http.get(secondUrl);
        if (secondResponse.statusCode == 200) {
          final secondData = json.decode(secondResponse.body);
          final secondResults = secondData['results'] as List;

          if (secondResults.isNotEmpty) {
            _updateMarkers(secondResults);
            return;
          }

          // If still no results, try 5km
          final widerUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&radius=5000'
            '&type=$type'
            '&key=$_apiKey',
          );

          final widerResponse = await http.get(widerUrl);
          if (widerResponse.statusCode == 200) {
            final widerData = json.decode(widerResponse.body);
            final widerResults = widerData['results'] as List;
            
            if (widerResults.isNotEmpty) {
              _updateMarkers(widerResults);
            } else {
              // If still no results, show error with API response
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No places found. API Response: ${widerResponse.body}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      } else {
        throw Exception('Failed to load places: ${initialResponse.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding nearby places: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkers(List<dynamic> results) {
    setState(() {
      _markers.clear();
      
      // Add current location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      // Add place markers
      for (var place in results) {
        final location = place['geometry']['location'];
        _markers.add(
          Marker(
            markerId: MarkerId(place['place_id']),
            position: LatLng(
              location['lat'],
              location['lng'],
            ),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: place['vicinity'],
            ),
          ),
        );
      }
    });

    // Zoom to show all markers
    if (_markers.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getBounds(_markers),
          100,
        ),
      );
    }
  }

  LatLngBounds _getBounds(Set<Marker> markers) {
    double? minLat, maxLat, minLng, maxLng;
    for (var marker in markers) {
      if (minLat == null || marker.position.latitude < minLat) {
        minLat = marker.position.latitude;
      }
      if (maxLat == null || marker.position.latitude > maxLat) {
        maxLat = marker.position.latitude;
      }
      if (minLng == null || marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (maxLng == null || marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _shareLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available yet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _locationService.startSharingLocation();
      final sharingLink = await _locationService.generateShareableLink();
      
      await Share.share(
        'Track my live location: $sharingLink',
        subject: 'My Live Location',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Location services are disabled',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: const Text('Enable Location'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                      markers: _markers,
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLocationButton(
                              Icons.local_police,
                              'Police',
                              () => _findNearbyPlaces('police'),
                            ),
                            _buildLocationButton(
                              Icons.local_hospital,
                              'Hospital',
                              () => _findNearbyPlaces('hospital'),
                            ),
                            _buildLocationButton(
                              Icons.local_pharmacy,
                              'Pharmacy',
                              () => _findNearbyPlaces('pharmacy'),
                            ),
                            _buildLocationButton(
                              Icons.directions_bus,
                              'Bus',
                              () => _findNearbyPlaces('bus_station'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildLocationButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 