import 'package:flutter/material.dart';

class SelfDefenseScreen extends StatelessWidget {
  const SelfDefenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Defense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTechniqueCard(
              context,
              'Basic Stance',
              'Stand with feet shoulder-width apart, knees slightly bent, and hands up to protect your face.',
              'assets/stance.png',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildTechniqueCard(
              context,
              'Palm Strike',
              'Use the heel of your palm to strike the attacker\'s nose or chin. Keep your fingers together and wrist straight.',
              'assets/palm_strike.png',
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildTechniqueCard(
              context,
              'Knee Strike',
              'Grab the attacker\'s shoulders and drive your knee into their groin or stomach.',
              'assets/knee_strike.png',
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildTechniqueCard(
              context,
              'Escape from Wrist Grab',
              'Twist your wrist against the attacker\'s thumb to break free from their grip.',
              'assets/wrist_escape.png',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildTechniqueCard(
              context,
              'Breaking Free from Bear Hug',
              'Drop your weight, stomp on their foot, and use your elbows to strike their ribs.',
              'assets/bear_hug.png',
              Colors.orange,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTechniqueCard(
    BuildContext context,
    String title,
    String description,
    String imagePath,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 