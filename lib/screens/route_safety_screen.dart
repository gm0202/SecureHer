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
  LatLng? _startLocation;
  LatLng? _endLocation;
  String? _startAddress;
  String? _endAddress;
  String _safetyScore = '';
  String _safetyDetails = '';
  bool _isLoading = false;
  static const String _openWeatherApiKey = '952bcbeab47c51bcaa99bdc453bfa01b0be80886';
  static const String _tomTomApiKey = 'wdBGBQfSW5hMJQCSSgcOriiFHKsVnRyK';
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isNightMode = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Helper method restored
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

  Future<void> _checkRouteSafety() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

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
      LatLng? startCoords = _startLocation;
      LatLng? endCoords = _endLocation;

      if (startCoords == null || endCoords == null) {
        throw Exception('Please select start and end locations from the suggestions list');
      }
      print('Coordinates found: $startCoords, $endCoords');

      print('Getting route from TomTom...');
      // Get route and traffic data from TomTom
      final routeData = await _getTomTomRoute(startCoords, endCoords);
      final routePoints = routeData['points'] as List<LatLng>;
      print('Route points: ${routePoints.length}');
      
      print('Calculating safety score...');
      // Calculate safety score using traffic data
      final safetyScore = await _calculateSafetyScore(routePoints, routeData);
      print('Safety score calculated: $safetyScore');
      
      // Update UI
      setState(() {
        _safetyScore = 'Safety Score: ${safetyScore['score']}/10';
        _safetyDetails = '''
Traffic Density: ${safetyScore['crowd']} (Safety Factor)
Weather Conditions: ${safetyScore['weather']}
Time: ${safetyScore['time']}
''';
      });

      // Update map
      _updateMap(startCoords, endCoords, routePoints);
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

  // Returns Map with 'points' (List<LatLng>) and 'trafficData' (Map)
  Future<Map<String, dynamic>> _getTomTomRoute(LatLng start, LatLng end) async {
    final url = 'https://api.tomtom.com/routing/1/calculateRoute/${start.latitude},${start.longitude}:${end.latitude},${end.longitude}/json?key=$_tomTomApiKey&traffic=true';
    print('TomTom URL: $url');
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final legs = route['legs'][0];
        final points = legs['points'] as List;
        
        // Parse points
        final List<LatLng> routePoints = points.map<LatLng>((point) {
          return LatLng(point['latitude'], point['longitude']);
        }).toList();

        final summary = route['summary'];
        return {
          'points': routePoints,
          'travelTimeInSeconds': summary['travelTimeInSeconds'],
          'trafficDelayInSeconds': summary['trafficDelayInSeconds'],
          'lengthInMeters': summary['lengthInMeters'],
        };
      } else {
        throw Exception('No route found in TomTom response');
      }
    } else {
      throw Exception('TomTom API Error: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _calculateSafetyScore(List<LatLng> route, Map<String, dynamic> routeData) async {
    print('Starting safety score calculation...');
    
    try {
      print('Getting weather data...');
      final weather = await _getWeatherData(route.first);
      print('Weather data received: $weather');
      
      print('Analyzing traffic density...');
      // Traffic Logic: More traffic = Safer
      // We calculate a ratio: (Traffic Delay / Base Travel Time)
      // If Traffic Delay is 0, ratio is 0 (Low Traffic -> Less Safe per your logic)
      // If Traffic Delay is high, ratio is high (High Traffic -> Safer)
      
      final int trafficDelay = routeData['trafficDelayInSeconds'] ?? 0;
      final int totalTime = routeData['travelTimeInSeconds'] ?? 1;
      
      // Calculate "Traffic Density Score" (0 to 10)
      // Assume if traffic adds > 20% to time, it's "Heavy Traffic" (Safe)
      // If traffic adds 0%, it's "No Traffic" (Unsafe)
      
      double trafficScore = 0;
      if (trafficDelay > 0) {
        // Calculate ratio of delay to normal time (approx)
        // normalTime = totalTime - trafficDelay
        double normalTime = (totalTime - trafficDelay).toDouble();
        if (normalTime <= 0) normalTime = 1;
        
        double ratio = trafficDelay / normalTime;
        // Map ratio to score
        // 0.0 -> 0 score
        // 0.1 (10% delay) -> 5 score
        // > 0.2 (20% delay) -> 10 score
        trafficScore = (ratio * 50).clamp(0, 10);
      } else {
         // Even with 0 delay, there might be cars, but per logic "more traffic = safer".
         // Let's verify TomTom returns 0 for "free flow".
         // We can fallback to a base score of 3 for "Active Road" 
         trafficScore = 3.0;
      }
      
      // Force high score if user wants "Heavy Traffic = Safe"
      // Wait, user said "suggest route with MOST traffic".
      // So high delay = High Score. Correct.
      
      print('Traffic Delay: $trafficDelay s, Score: $trafficScore');

      print('Calculating time score...');
      final timeScore = _calculateTimeScore();
      print('Time score calculated: $timeScore');

      // Calculate final score
      // Traffic: 50%, Weather: 25%, Time: 25%
      final score = (
        (trafficScore * 0.5) + 
        (weather * 0.25) +
        (timeScore * 0.25)
      ).round();

      print('Final score: $score');

      return {
        'score': score.clamp(0, 10),
        'crowd': _getTrafficText(trafficScore),
        'weather': _getWeatherText(weather),
        'time': _isNightMode ? 'Night' : 'Day',
      };
    } catch (e) {
      print('Error in _calculateSafetyScore: $e');
      return {
        'score': 5,
        'crowd': 'Unknown',
        'weather': 'Moderate',
        'time': _isNightMode ? 'Night' : 'Day',
      };
    }
  }

  String _getTrafficText(double score) {
    if (score > 7) return 'High Traffic (Safe)';
    if (score > 4) return 'Moderate Traffic';
    return 'Low Traffic (Caution)';
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





  String _getWeatherText(double score) {
    if (score < 3) return 'Poor';
    if (score < 7) return 'Moderate';
    return 'Good';
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



  void _updateMap(LatLng start, LatLng end, List<LatLng> route) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: start,
          infoWindow: const InfoWindow(title: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: end,
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
    if (points.isEmpty) return LatLngBounds(southwest: const LatLng(0,0), northeast: const LatLng(0,0));
    
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

  Future<List<Map<String, dynamic>>> _getPlaceSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'countrycodes': 'in',
        'limit': '5',
        'addressdetails': '1',
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'SecureHer App',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return (data as List).map((place) => {
            'display_name': place['display_name'] as String,
            'lat': double.parse(place['lat']),
            'lon': double.parse(place['lon']),
          }).toList();
        } else {
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Route Safety Checker'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TypeAheadField<Map<String, dynamic>>(
                  controller: _startController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Start Location',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // User is typing manually, we could clear location but 
                        // for now we trust the selection or require re-selection.
                        // To follow strict "Select from list" logic, 
                        // we can reset if empty or just rely on the strict check at submit.
                        if (value.isEmpty) {
                           _startLocation = null;
                        }
                      },
                    );
                  },
                  suggestionsCallback: (pattern) => _getPlaceSuggestions(pattern),
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['display_name']),
                    );
                  },
                  onSelected: (suggestion) {
                    _startController.text = suggestion['display_name'];
                    setState(() {
                      _startAddress = suggestion['display_name'];
                      _startLocation = LatLng(suggestion['lat'], suggestion['lon']);
                    });
                  },
                ),
                const SizedBox(height: 16),
                TypeAheadField<Map<String, dynamic>>(
                  controller: _endController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'End Location',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                         if (value.isEmpty) {
                           _endLocation = null;
                         }
                      },
                    );
                  },
                  suggestionsCallback: (pattern) => _getPlaceSuggestions(pattern),
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['display_name']),
                    );
                  },
                  onSelected: (suggestion) {
                    _endController.text = suggestion['display_name'];
                    setState(() {
                      _endAddress = suggestion['display_name'];
                      _endLocation = LatLng(suggestion['lat'], suggestion['lon']);
                    });
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