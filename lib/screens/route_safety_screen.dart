import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:secureher/theme/app_theme.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class RouteSafetyScreen extends StatefulWidget {
  const RouteSafetyScreen({super.key});

  @override
  State<RouteSafetyScreen> createState() => _RouteSafetyScreenState();
}

class _RouteSafetyScreenState extends State<RouteSafetyScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _safetyScore = '';
  String _safetyDetails = '';
  bool _isLoading = false;
  static const String _openWeatherApiKey = '952bcbeab47c51bcaa99bdc453bfa01b0be80886';
  static const String _googleMapsApiKey = 'AIzaSyA0kHChkc5NHL0Eoh4JzBKR6KyepOUWRGU';
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isNightMode = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkRouteSafety() async {
    if (_startController.text.isEmpty || _endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both start and end locations')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _safetyScore = '';
      _safetyDetails = '';
    });

    try {
      print('Getting coordinates...');
      // Get coordinates for start and end points
      final startCoords = await _getCoordinates(_startController.text);
      final endCoords = await _getCoordinates(_endController.text);

      if (startCoords == null || endCoords == null) {
        throw Exception('Could not find locations');
      }
      print('Coordinates found: $startCoords, $endCoords');

      print('Getting route...');
      // Get route from OSM
      final route = await _getOSMRoute(startCoords, endCoords);
      print('Route points: ${route.length}');
      
      print('Calculating safety score...');
      // Calculate safety score
      final safetyScore = await _calculateSafetyScore(route);
      print('Safety score calculated: $safetyScore');
      
      // Update UI
      setState(() {
        _safetyScore = 'Safety Score: ${safetyScore['score']}/10';
        _safetyDetails = '''
Streetlight Coverage: ${safetyScore['streetlight']}%
Crowd Density: ${safetyScore['crowd']}
Weather Conditions: ${safetyScore['weather']}
Incidents: ${safetyScore['incidents']}
Time: ${safetyScore['time']}
''';
      });

      // Update map
      _updateMap(startCoords, endCoords, route);
    } catch (e) {
      print('Error in _checkRouteSafety: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getCoordinates(String address) async {
    final response = await http.get(Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=$address',
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        return {
          'lat': double.parse(data[0]['lat']),
          'lng': double.parse(data[0]['lon']),
        };
      }
    }
    return null;
  }

  Future<List<LatLng>> _getOSMRoute(Map<String, dynamic> start, Map<String, dynamic> end) async {
    try {
      print('Getting route from OSRM...');
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start['lng']},${start['lat']};${end['lng']},${end['lat']}'
        '?overview=full&geometries=geojson&steps=true',
      ));

      print('OSRM Response status: ${response.statusCode}');
      print('OSRM Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'];
          print('Route coordinates found: ${coordinates.length} points');
          return coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        } else {
          throw Exception('No route found in response');
        }
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _getOSMRoute: $e');
      // Fallback to a simple straight line route if OSRM fails
      print('Using fallback straight line route');
      return [
        LatLng(start['lat'], start['lng']),
        LatLng(end['lat'], end['lng']),
      ];
    }
  }

  Future<Map<String, dynamic>> _calculateSafetyScore(List<LatLng> route) async {
    print('Starting safety score calculation...');
    
    try {
      print('Getting weather data...');
      final weather = await _getWeatherData(route.first);
      print('Weather data received: $weather');
      
      print('Estimating streetlight coverage...');
      final streetlightCoverage = await _estimateStreetlightCoverage(route);
      print('Streetlight coverage calculated: $streetlightCoverage');
      
      print('Estimating crowd density...');
      final crowdDensity = await _estimateCrowdDensity(route);
      print('Crowd density calculated: $crowdDensity');

      print('Getting incident data...');
      final incidentScore = await _getIncidentData(route);
      print('Incident data received: $incidentScore');

      print('Calculating time score...');
      final timeScore = _calculateTimeScore();
      print('Time score calculated: $timeScore');

      // Calculate final score with new weights
      final score = (
        (streetlightCoverage * 0.2) + 
        (crowdDensity * 0.3) + 
        (weather * 0.2) +
        (incidentScore * 0.3)
      ).round();

      // Apply time-based adjustment
      final adjustedScore = _isNightMode ? score * 0.8 : score;
      print('Final adjusted score: $adjustedScore');

      return {
        'score': adjustedScore.clamp(0, 10),
        'streetlight': streetlightCoverage,
        'crowd': _getCrowdDensityText(crowdDensity),
        'weather': _getWeatherText(weather),
        'incidents': _getIncidentText(incidentScore),
        'time': _isNightMode ? 'Night' : 'Day',
      };
    } catch (e) {
      print('Error in _calculateSafetyScore: $e');
      // Return default values if calculation fails
      return {
        'score': 5,
        'streetlight': 50,
        'crowd': 'Medium',
        'weather': 'Moderate',
        'incidents': 'Moderate Risk',
        'time': _isNightMode ? 'Night' : 'Day',
      };
    }
  }

  Future<double> _getWeatherData(LatLng location) async {
    final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=${location.latitude}&lon=${location.longitude}&appid=$_openWeatherApiKey&units=metric',
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _calculateWeatherScore(data);
    }
    return 5.0; // Default score if API fails
  }

  Future<double> _estimateStreetlightCoverage(List<LatLng> route) async {
    // Query OSM for streetlight data along the route
    double totalDistance = 0;
    double litDistance = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final distance = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      totalDistance += distance;

      // Query OSM for streetlights in this segment
      final response = await http.get(Uri.parse(
        'https://overpass-api.de/api/interpreter?data=[out:json];way[highway][lit=yes](${start.latitude},${start.longitude},${end.latitude},${end.longitude});out;',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'].isNotEmpty) {
          litDistance += distance;
        }
      }
    }

    return totalDistance > 0 ? (litDistance / totalDistance) * 100 : 0;
  }

  Future<double> _estimateCrowdDensity(List<LatLng> route) async {
    // Sample points along the route
    final samplePoints = _getSamplePoints(route, 5);
    double totalDensity = 0;

    for (final point in samplePoints) {
      // Query OSM for nearby amenities
      final response = await http.get(Uri.parse(
        'https://overpass-api.de/api/interpreter?data=[out:json];'
        'node[amenity](${point.latitude-0.001},${point.longitude-0.001},${point.latitude+0.001},${point.longitude+0.001});'
        'out;',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final placesCount = data['elements'].length;
        // Higher density if more amenities are found
        totalDensity += placesCount > 10 ? 8.0 : placesCount > 5 ? 6.0 : 4.0;
      } else {
        print('Error getting crowd density: ${response.statusCode}');
      }
    }

    return samplePoints.isNotEmpty ? totalDensity / samplePoints.length : 5.0;
  }

  List<LatLng> _getSamplePoints(List<LatLng> route, int count) {
    if (route.length <= count) return route;
    
    final step = (route.length - 1) ~/ (count - 1);
    return List.generate(count, (index) => route[index * step]);
  }

  double _calculateWeatherScore(Map<String, dynamic> weatherData) {
    final weather = weatherData['weather'][0]['main'];
    final temp = weatherData['main']['temp'];
    final visibility = weatherData['visibility'] / 1000; // Convert to km

    double score = 7.0; // Base score

    // Adjust score based on weather conditions
    switch (weather) {
      case 'Clear':
        score += 2;
        break;
      case 'Clouds':
        score += 1;
        break;
      case 'Rain':
      case 'Drizzle':
        score -= 2;
        break;
      case 'Thunderstorm':
        score -= 3;
        break;
      case 'Snow':
        score -= 2;
        break;
      case 'Fog':
      case 'Mist':
        score -= 3;
        break;
    }

    // Adjust for temperature (comfortable range: 15-25°C)
    if (temp < 5 || temp > 30) {
      score -= 2;
    } else if (temp < 10 || temp > 25) {
      score -= 1;
    }

    // Adjust for visibility
    if (visibility < 1) {
      score -= 2;
    } else if (visibility < 3) {
      score -= 1;
    }

    return score.clamp(0, 10);
  }

  String _getCrowdDensityText(double density) {
    if (density < 3) return 'Low';
    if (density < 7) return 'Medium';
    return 'High';
  }

  String _getWeatherText(double score) {
    if (score < 3) return 'Poor';
    if (score < 7) return 'Moderate';
    return 'Good';
  }

  Future<double> _getIncidentData(List<LatLng> route) async {
    double totalScore = 0;
    int sampleCount = 0;

    // Sample points along the route
    final samplePoints = _getSamplePoints(route, 5);

    for (final point in samplePoints) {
      // Query OSM for police stations and hospitals nearby
      final response = await http.get(Uri.parse(
        'https://overpass-api.de/api/interpreter?data=[out:json];'
        'node[amenity=police|hospital](${point.latitude-0.002},${point.longitude-0.002},${point.latitude+0.002},${point.longitude+0.002});'
        'out;',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final safetyPlaces = data['elements'].length;
        
        // Higher score if more safety-related places are nearby
        totalScore += safetyPlaces > 3 ? 8.0 : safetyPlaces > 1 ? 6.0 : 4.0;
        sampleCount++;
      } else {
        print('Error getting incident data: ${response.statusCode}');
      }
    }

    return sampleCount > 0 ? totalScore / sampleCount : 5.0;
  }

  double _calculateTimeScore() {
    final hour = _selectedTime.hour;
    
    // Score based on time of day
    if (hour >= 6 && hour < 18) {
      return 8.0; // Daytime
    } else if (hour >= 18 && hour < 22) {
      return 6.0; // Evening
    } else {
      return 4.0; // Night
    }
  }

  String _getIncidentText(double score) {
    if (score < 4) return 'High Risk';
    if (score < 7) return 'Moderate Risk';
    return 'Low Risk';
  }

  void _updateMap(Map<String, dynamic> start, Map<String, dynamic> end, List<LatLng> route) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(start['lat'], start['lng']),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(end['lat'], end['lng']),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      };

      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: route,
          color: Colors.blue,
          width: 5,
        ),
      };
    });

    // Move camera to show the entire route
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        _getBounds(route),
        50.0,
      ),
    );
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    
    for (var point in points) {
      minLat = minLat == null ? point.latitude : min(minLat, point.latitude);
      maxLat = maxLat == null ? point.latitude : max(maxLat, point.latitude);
      minLng = minLng == null ? point.longitude : min(minLng, point.longitude);
      maxLng = maxLng == null ? point.longitude : max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _isNightMode = picked.hour >= 18 || picked.hour < 6;
      });
    }
  }

  Future<List<String>> _getPlaceSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=json'
        '&q=$query'
        '&countrycodes=in'  // Restrict to India
        '&limit=5'  // Limit to 5 results
        '&addressdetails=1',
      ), headers: {
        'User-Agent': 'SecureHer App',  // Required by Nominatim
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return (data as List)
              .map((place) => place['display_name'] as String)
              .toList();
        } else {
          print('No results found');
          return [];
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching place suggestions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Safety Checker'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TypeAheadField<String>(
                  controller: _startController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Start Location',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) => _getPlaceSuggestions(pattern),
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion),
                    );
                  },
                  onSelected: (suggestion) {
                    _startController.text = suggestion;
                  },
                ),
                const SizedBox(height: 16),
                TypeAheadField<String>(
                  controller: _endController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'End Location',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) => _getPlaceSuggestions(pattern),
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion),
                    );
                  },
                  onSelected: (suggestion) {
                    _endController.text = suggestion;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _selectTime(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Time: ${_selectedTime.format(context)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkRouteSafety,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Check Route Safety'),
                ),
              ],
            ),
          ),
          if (_safetyScore.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _safetyScore,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _safetyDetails,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 2,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
} 