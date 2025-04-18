import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class HiddenCameraDetector extends StatefulWidget {
  const HiddenCameraDetector({super.key});

  @override
  State<HiddenCameraDetector> createState() => _HiddenCameraDetectorState();
}

class _HiddenCameraDetectorState extends State<HiddenCameraDetector> {
  bool _isDetecting = false;
  bool _isDetected = false;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _lastResultant = 0.0;
  int _beepCount = 0;
  Timer? _beepTimer;

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _audioPlayer.dispose();
    _beepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDetection() async {
    final status = await Permission.sensors.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sensor permission is required')),
      );
      return;
    }

    setState(() {
      _isDetecting = true;
      _isDetected = false;
      _beepCount = 0;
    });

    _magnetometerSubscription = magnetometerEvents.listen((event) {
      final resultant = sqrt(
        pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
      );

      if (_lastResultant == 0.0) {
        _lastResultant = resultant;
        return;
      }

      final difference = (resultant - _lastResultant).abs();
      _lastResultant = resultant;

      if (difference > 50 && _beepCount < 3) {
        setState(() {
          _isDetected = true;
          _beepCount++;
        });
        _playBeep();
      }
    });

    _beepTimer = Timer(const Duration(seconds: 10), () {
      setState(() {
        _isDetecting = false;
        _isDetected = false;
      });
      _magnetometerSubscription?.cancel();
    });
  }

  Future<void> _playBeep() async {
    await _audioPlayer.play(AssetSource('beep.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _isDetected
                  ? Colors.red.shade400
                  : _isDetecting
                      ? Colors.blue.shade400
                      : Colors.grey.shade300,
              _isDetected
                  ? Colors.red.shade600
                  : _isDetecting
                      ? Colors.blue.shade600
                      : Colors.grey.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDetected
                      ? Icons.warning_rounded
                      : Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hidden Camera Detector',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isDetected
                  ? 'Potential hidden camera detected!'
                  : _isDetecting
                      ? 'Scanning for hidden cameras...'
                      : 'Detect hidden cameras in your surroundings',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isDetecting ? null : _startDetection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _isDetecting
                    ? Colors.blue.shade400
                    : Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                _isDetecting ? 'Scanning...' : 'Start Detection',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 