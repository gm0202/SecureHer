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

      // Map Google Places types to OSM tags
      String osmTag = '';
      switch (type) {
        case 'police':
          osmTag = 'amenity=police';
          break;
        case 'hospital':
          osmTag = 'amenity=hospital';
          break;
        case 'pharmacy':
          osmTag = 'amenity=pharmacy';
          break;
        case 'bus_station':
          osmTag = 'amenity=bus_station';
          break;
        default:
          osmTag = 'amenity=$type';
      }

      // Calculate bounding box (approximately 1km radius)
      final lat = _currentPosition!.latitude;
      final lon = _currentPosition!.longitude;
      final radius = 0.01; // Approximately 1km
      
      // Query OSM for nearby places using a more comprehensive search
      final response = await http.get(Uri.parse(
        'https://overpass-api.de/api/interpreter?data=[out:json];'
        '(node[$osmTag](${lat-radius},${lon-radius},${lat+radius},${lon+radius});'
        'way[$osmTag](${lat-radius},${lon-radius},${lat+radius},${lon+radius});'
        'relation[$osmTag](${lat-radius},${lon-radius},${lat+radius},${lon+radius}););'
        'out body;>;out skel qt;',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'] != null && data['elements'].isNotEmpty) {
          _updateMarkers(data['elements']);
        } else {
          // If no results in initial area, try a wider area (approximately 5km)
          final widerRadius = 0.05;
          final widerResponse = await http.get(Uri.parse(
            'https://overpass-api.de/api/interpreter?data=[out:json];'
            '(node[$osmTag](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius});'
            'way[$osmTag](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius});'
            'relation[$osmTag](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius}););'
            'out body;>;out skel qt;',
          ));

          if (widerResponse.statusCode == 200) {
            final widerData = json.decode(widerResponse.body);
            if (widerData['elements'] != null && widerData['elements'].isNotEmpty) {
              _updateMarkers(widerData['elements']);
            } else {
              // If still no results, try a generic search
              final genericResponse = await http.get(Uri.parse(
                'https://overpass-api.de/api/interpreter?data=[out:json];'
                '(node[amenity](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius});'
                'way[amenity](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius});'
                'relation[amenity](${lat-widerRadius},${lon-widerRadius},${lat+widerRadius},${lon+widerRadius}););'
                'out body;>;out skel qt;',
              ));

              if (genericResponse.statusCode == 200) {
                final genericData = json.decode(genericResponse.body);
                if (genericData['elements'] != null && genericData['elements'].isNotEmpty) {
                  // Filter for the specific type we're looking for
                  final filteredElements = genericData['elements'].where((element) {
                    final tags = element['tags'] as Map<String, dynamic>?;
                    return tags != null && tags['amenity'] == type;
                  }).toList();
                  
                  if (filteredElements.isNotEmpty) {
                    _updateMarkers(filteredElements);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No places found in the area'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No places found in the area'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            }
          }
        }
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
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

  void _updateMarkers(List<dynamic> places) {
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
      for (var place in places) {
        try {
          if (place['type'] == 'node' || place['type'] == 'way' || place['type'] == 'relation') {
            final tags = place['tags'] as Map<String, dynamic>?;
            if (tags != null) {
              final name = tags['name'] ?? 'Unnamed Place';
              final address = tags['addr:street'] ?? '';
              
              // Get coordinates based on element type
              double? lat, lon;
              
              if (place['type'] == 'node') {
                lat = place['lat'] as double?;
                lon = place['lon'] as double?;
              } else if (place['type'] == 'way' || place['type'] == 'relation') {
                // For ways and relations, try to get center coordinates
                if (place['center'] != null) {
                  lat = place['center']['lat'] as double?;
                  lon = place['center']['lon'] as double?;
                } else if (place['lat'] != null && place['lon'] != null) {
                  lat = place['lat'] as double?;
                  lon = place['lon'] as double?;
                }
              }

              // Only add marker if we have valid coordinates
              if (lat != null && lon != null) {
                _markers.add(
                  Marker(
                    markerId: MarkerId(place['id'].toString()),
                    position: LatLng(lat, lon),
                    infoWindow: InfoWindow(
                      title: name,
                      snippet: address,
                    ),
                  ),
                );
              }
            }
          }
        } catch (e) {
          // Skip this place if there's an error processing it
          continue;
        }
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