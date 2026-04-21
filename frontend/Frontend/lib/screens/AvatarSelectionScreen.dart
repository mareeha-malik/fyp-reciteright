import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  String? selectedAvatar;
  bool isLoading = false;

  // Avatar image options
  final List<Map<String, dynamic>> avatarOptions = [
    {'image': 'assets/Avatars/01ff103dafc5d35c06cb142c5311dfe9.jpg', 'name': 'Avatar 1', 'label': 'Avatar 1'},
    {'image': 'assets/Avatars/25f7a39ab0e555c876bb0fff022adb19.jpg', 'name': 'Avatar 2', 'label': 'Avatar 2'},
    {'image': 'assets/Avatars/48cad407e57661248b7956d75ef6ad40.jpg', 'name': 'Avatar 3', 'label': 'Avatar 3'},
    {'image': 'assets/Avatars/6178467ae990b505a8e50e1216b5b666.jpg', 'name': 'Avatar 4', 'label': 'Avatar 4'},
    {'image': 'assets/Avatars/a8740345870b091fa2fee71c06dad7e7.jpg', 'name': 'Avatar 5', 'label': 'Avatar 5'},
    {'image': 'assets/Avatars/b1e22f618ea125bd5eea9a502f7ca22a.jpg', 'name': 'Avatar 6', 'label': 'Avatar 6'},
    {'image': 'assets/Avatars/b557418f1715cd9647a13299930e65a4.jpg', 'name': 'Avatar 7', 'label': 'Avatar 7'},
    {'image': 'assets/Avatars/e1aaea8420d4d2fa5d5f25f65d621470.jpg', 'name': 'Avatar 8', 'label': 'Avatar 8'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentAvatar();
  }

  Future<void> _loadCurrentAvatar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            selectedAvatar = doc['avatar'] ?? avatarOptions[0]['image'];
          });
        } else if (mounted) {
          setState(() {
            selectedAvatar = avatarOptions[0]['image'];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading avatar: $e');
      if (mounted) {
        setState(() {
          selectedAvatar = avatarOptions[0]['image'];
        });
      }
    }
  }

  Future<void> _saveAvatar(String avatarPath) async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      print('💾 Saving avatar: $avatarPath');

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'avatar': avatarPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((error) async {
        // If document doesn't exist, create it
        if (error.code == 'not-found' || error.toString().contains('FAILED_PRECONDITION')) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'avatar': avatarPath,
            'email': user.email,
            'fullName': user.displayName ?? 'User',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          throw error;
        }
      });

      if (mounted) {
        setState(() {
          selectedAvatar = avatarPath;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Avatar saved successfully!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E4976),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving avatar: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Choose Your Avatar'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF1E4976).withValues(alpha: 0.3),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E4976),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current Avatar Preview Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E4976).withValues(alpha: 0.1),
                          const Color(0xFF2E5F8F).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E4976).withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Text(
                          'Your Current Avatar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E4976).withValues(alpha: 0.15),
                                const Color(0xFF2E5F8F).withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E4976),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E4976).withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: ClipOval(
                            child: Image.asset(
                              selectedAvatar ?? avatarOptions[0]['image'],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[200],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getAvatarLabel(selectedAvatar ?? avatarOptions[0]['image']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E4976),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Avatar Selection Grid
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E4976).withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 0, bottom: 16),
                          child: Text(
                            'Select Avatar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E4976),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: avatarOptions.length,
                          itemBuilder: (context, index) {
                            final avatar = avatarOptions[index];
                            final isSelected = selectedAvatar == avatar['image'];

                            return AnimatedScale(
                              scale: isSelected ? 1.05 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () => _saveAvatar(avatar['image']),
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF1E4976)
                                              : Colors.grey[200]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF1E4976)
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          avatar['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey[400],
                                                  size: 30,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1E4976),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enhanced Legend with categories
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E4976).withValues(alpha: 0.08),
                          const Color(0xFF1E4976).withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1E4976).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF1E4976),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Avatar Legend',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E4976),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: avatarOptions.map((avatar) {
                            return Chip(
                              label: Text(
                                '${avatar['emoji']} ${avatar['label']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: const Color(0xFF1E4976)
                                      .withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _getAvatarLabel(String imagePath) {
    // Map each image path to a label
    const labelMap = {
      'assets/Avatars/01ff103dafc5d35c06cb142c5311dfe9.jpg': 'Avatar 1',
      'assets/Avatars/25f7a39ab0e555c876bb0fff022adb19.jpg': 'Avatar 2',
      'assets/Avatars/48cad407e57661248b7956d75ef6ad40.jpg': 'Avatar 3',
      'assets/Avatars/6178467ae990b505a8e50e1216b5b666.jpg': 'Avatar 4',
      'assets/Avatars/a8740345870b091fa2fee71c06dad7e7.jpg': 'Avatar 5',
      'assets/Avatars/b1e22f618ea125bd5eea9a502f7ca22a.jpg': 'Avatar 6',
      'assets/Avatars/b557418f1715cd9647a13299930e65a4.jpg': 'Avatar 7',
      'assets/Avatars/e1aaea8420d4d2fa5d5f25f65d621470.jpg': 'Avatar 8',
    };
    return labelMap[imagePath] ?? 'Avatar';
  }
}


