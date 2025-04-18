import 'package:flutter/material.dart';
import 'package:secureher/widgets/hidden_camera_detector.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraDetectorScreen extends StatefulWidget {
  const CameraDetectorScreen({super.key});

  @override
  State<CameraDetectorScreen> createState() => _CameraDetectorScreenState();
}

class _CameraDetectorScreenState extends State<CameraDetectorScreen> {
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final status = await Permission.sensors.status;
    
    if (status.isDenied) {
      final result = await Permission.sensors.request();
      setState(() {
        _hasPermission = result.isGranted;
        _isLoading = false;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
      });
      _showPermissionDeniedDialog();
    } else {
      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Sensor permission is required to use the camera detector. Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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
              else if (!_hasPermission)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.sensors_off,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sensor permission required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please grant sensor permission to use the camera detector.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkPermissions,
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                )
              else
                const HiddenCameraDetector(),
            ],
          ),
        ),
      ),
    );
  }
} 