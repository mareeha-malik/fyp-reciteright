import 'package:flutter/material.dart';

class QariListenScreen extends StatefulWidget {
  const QariListenScreen({super.key});

  @override
  State<QariListenScreen> createState() => _QariListenScreenState();
}

class _QariListenScreenState extends State<QariListenScreen> {
  final List<Map<String, String>> qaris = [
    {
      'name': 'Mishary Al-Afasy',
      'speciality': 'Clear Tajweed',
      'image': 'assets/Reciter.png',
    },
    {
      'name': 'Abdul-Rahman Al-Sudais',
      'speciality': 'Emotional Recitation',
      'image': 'assets/Reciter.png',
    },
    {
      'name': 'Saad Al-Ghamidi',
      'speciality': 'Melodious Voice',
      'image': 'assets/Reciter.png',
    },
    {
      'name': 'Muhammad Al-Luhaidan',
      'speciality': 'Clear Pronunciation',
      'image': 'assets/Reciter.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Listen to Qaris'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF1E4976).withValues(alpha: 0.3),
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Your Favorite Qari',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E4976),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Listen to beautiful recitations with proper Tajweed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Qaris List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: qaris.length,
              itemBuilder: (context, index) {
                final qari = qaris[index];
                return GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playing ${qari['name']}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E4976).withValues(alpha: 0.1),
                            const Color(0xFF1E4976).withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: const Color(0xFF1E4976),
                            child: Image.asset(
                              qari['image']!,
                              fit: BoxFit.cover,
                              width: 70,
                              height: 70,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  qari['name']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E4976),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  qari['speciality']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Play Button
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E4976),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.play_arrow),
                              color: Colors.white,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Playing ${qari['name']}'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


