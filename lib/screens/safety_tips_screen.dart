import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Tips'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSafetyTipCard(
                context,
                'General Safety',
                [
                  'Always be aware of your surroundings',
                  'Keep your phone charged and with you',
                  'Share your location with trusted contacts',
                  'Trust your instincts - if something feels wrong, it probably is',
                  'Learn basic self-defense techniques',
                ],
                Icons.security,
                Colors.pink,
              ),
              const SizedBox(height: 8),
              _buildSafetyTipCard(
                context,
                'Public Transportation',
                [
                  'Sit near the driver or in well-lit areas',
                  'Keep your belongings close to you',
                  'Avoid using headphones at high volume',
                  'Have your phone ready to call for help',
                  'Know the emergency numbers for your area',
                ],
                Icons.directions_bus,
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildSafetyTipCard(
                context,
                'Online Safety',
                [
                  'Be careful about sharing personal information online',
                  'Use strong, unique passwords',
                  'Enable two-factor authentication',
                  'Be cautious when meeting people from online',
                  'Report suspicious behavior to authorities',
                ],
                Icons.lock,
                Colors.purple,
              ),
              const SizedBox(height: 8),
              _buildSafetyTipCard(
                context,
                'Emergency Preparedness',
                [
                  'Save emergency contacts in your phone',
                  'Know the quickest route to safe places',
                  'Keep a small emergency kit with you',
                  'Practice emergency scenarios',
                  'Stay calm and think clearly in emergencies',
                ],
                Icons.emergency,
                Colors.red,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyTipCard(
    BuildContext context,
    String title,
    List<String> tips,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
} 