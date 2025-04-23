import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';

class HiddenCameraDetector extends StatefulWidget {
  const HiddenCameraDetector({Key? key}) : super(key: key);

  @override
  _HiddenCameraDetectorState createState() => _HiddenCameraDetectorState();
}

class _HiddenCameraDetectorState extends State<HiddenCameraDetector> {
  final _audioPlayer = AudioPlayer();
  StreamSubscription<MagnetometerEvent>? _subscription;
  bool _isDetecting = false;
  bool _hasError = false;
  String? _errorMessage;
  int _counter = 0;
  double _currentStrength = 0.0;
  double _maxStrength = 0.0;
  bool _cameraDetected = false;
  Timer? _detectionTimer;
  String? _detectionDistance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDetection();
    });
  }

  String _getDistanceFromStrength(double strength) {
    if (strength > 500) {
      return 'Very Close (0-1 feet)';
    } else if (strength > 200) {
      return 'Close (1-3 feet)';
    } else if (strength > 100) {
      return 'Nearby (3-5 feet)';
    } else if (strength > 50) {
      return 'Moderate Distance (5-8 feet)';
    } else {
      return 'Far (8+ feet)';
    }
  }

  Future<void> _startDetection() async {
    try {
      print('Starting camera detection...');
      setState(() {
        _isDetecting = true;
        _hasError = false;
        _errorMessage = null;
        _maxStrength = 0.0;
        _cameraDetected = false;
        _detectionDistance = null;
      });

      _subscription = magnetometerEvents.listen(
        (MagnetometerEvent event) {
          try {
            // Calculate magnetic field strength
            final strength = sqrt(
              event.x * event.x + 
              event.y * event.y + 
              event.z * event.z
            );
            
            setState(() {
              _currentStrength = strength;
              if (strength > _maxStrength) {
                _maxStrength = strength;
              }
            });
            
            // Print strength every 50 readings for debugging
            _counter++;
            if (_counter % 50 == 0) {
              print('Magnetometer strength: $strength');
            }
            
            // If magnetic field strength is above threshold, potential camera detected
            if (strength > 50) { // Increased threshold for more accurate detection
              print('Potential camera detected! Magnetic field strength: $strength');
              _handleCameraDetection(strength);
            }
          } catch (e) {
            print('Error processing magnetometer data: $e');
          }
        },
        onError: (error) {
          print('Magnetometer error: $error');
          setState(() {
            _hasError = true;
            _errorMessage = 'Error reading sensor data. Please try again.';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Error starting detection: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error starting camera detection. Please try again.';
      });
    }
  }

  void _handleCameraDetection(double strength) {
    if (!_cameraDetected) {
      setState(() {
        _cameraDetected = true;
        _detectionDistance = _getDistanceFromStrength(strength);
      });
      _playBeep();
      
      // Reset detection after 5 seconds
      _detectionTimer?.cancel();
      _detectionTimer = Timer(const Duration(seconds: 5), () {
        setState(() {
          _cameraDetected = false;
          _detectionDistance = null;
        });
      });
    }
  }

  void _stopDetection() {
    _subscription?.cancel();
    _detectionTimer?.cancel();
    setState(() {
      _isDetecting = false;
      _cameraDetected = false;
      _detectionDistance = null;
    });
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.play(AssetSource('beep.mp3'));
    } catch (e) {
      print('Error playing beep sound: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _detectionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          if (_cameraDetected)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Camera Detected!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Approximate Distance: ${_detectionDistance ?? 'Unknown'}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          if (_isDetecting)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Scanning for hidden cameras...',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Move your device around the room to detect magnetic fields',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Strength: ${_currentStrength.toStringAsFixed(2)} µT',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Maximum Strength: ${_maxStrength.toStringAsFixed(2)} µT',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _stopDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop Scanning'),
                ),
              ],
            )
          else
            Column(
              children: [
                if (_maxStrength > 0)
                  Column(
                    children: [
                      Text(
                        'Last Maximum Strength: ${_maxStrength.toStringAsFixed(2)} µT',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ElevatedButton(
                  onPressed: _startDetection,
                  child: const Text('Start Detection'),
                ),
              ],
            ),
        ],
      ),
    );
  }
} 