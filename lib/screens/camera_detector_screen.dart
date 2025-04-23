import 'package:flutter/material.dart';
import 'package:secureher/widgets/hidden_camera_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class CameraDetectorScreen extends StatefulWidget {
  const CameraDetectorScreen({super.key});

  @override
  State<CameraDetectorScreen> createState() => _CameraDetectorScreenState();
}

class _CameraDetectorScreenState extends State<CameraDetectorScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    try {
      // No need to request permissions for magnetometer
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      print('Error initializing detector: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error initializing camera detector. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Detector'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hidden Camera Detection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use this tool to detect hidden cameras in your surroundings. The detector uses your device\'s magnetometer to identify potential hidden cameras.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_hasError)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'An error occurred',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeDetector,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              else
                const Expanded(
                  child: HiddenCameraDetector(),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 