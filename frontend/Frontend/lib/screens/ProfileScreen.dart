import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajweed_corrector/services/user_service.dart';
import 'package:tajweed_corrector/screens/Loginpage.dart';
import 'package:tajweed_corrector/screens/AvatarSelectionScreen.dart';
import 'package:tajweed_corrector/widgets/index.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();

  Map<String, dynamic> userProfile = {};
  String? avatar;
  bool _isLoading = true;
  bool _dailyReminderEnabled = true;
  bool _soundFeedbackEnabled = true;
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarScaleAnimation;

  @override
  void initState() {
    super.initState();
    _avatarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _avatarScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _avatarAnimationController, curve: Curves.elasticOut),
    );
    _avatarAnimationController.forward();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final profile = await _userService.getUserProfile();

    if (mounted) {
      setState(() {
        userProfile = profile ?? {};
        avatar = profile?['avatar'];
        _isLoading = false;
      });
    }
  }

  Future<void> _selectAvatar() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AvatarSelectionScreen()),
      );
      if (result != null && mounted) {
        _avatarAnimationController.reset();
        _avatarAnimationController.forward();
        setState(() {
          avatar = result;
        });
        _loadProfileData(); // Reload to sync with Firestore
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting avatar: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
        }
      }
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectAvatar();
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('Choose from Avatar List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4976),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = userProfile['fullName'] ?? user?.displayName ?? 'User';
    final email = user?.email ?? 'No email';
    final joined = _formatMemberSince(userProfile['createdAt']);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: const Color(0xFF1E4976),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4976)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF1E4976).withValues(alpha: 0.3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E4976),
                    const Color(0xFF2E5F8F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E4976).withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      ScaleTransition(
                        scale: _avatarScaleAnimation,
                        child: GestureDetector(
                          onTap: () => _showAvatarOptions(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                            child: AnimatedAvatar(
                              imagePath: (avatar != null && avatar!.isNotEmpty) ? avatar : null,
                              size: 100,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AvatarSelectionScreen(),
                                  ),
                                );
                              },
                            ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _showAvatarOptions(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E4976),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Member since $joined',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _profileInfoTile(
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    value: displayName,
                  ),
                  _profileInfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  _profileInfoTile(
                    icon: Icons.fingerprint,
                    label: 'User ID',
                    value: user?.uid ?? 'Unavailable',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Daily reminder'),
                    subtitle: const Text('Get notified to practice every day'),
                    value: _dailyReminderEnabled,
                    onChanged: (value) {
                      setState(() => _dailyReminderEnabled = value);
                    },
                    activeThumbColor: const Color(0xFF1E4976),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Audio feedback'),
                    subtitle: const Text('Play quick feedback sounds after recitation'),
                    value: _soundFeedbackEnabled,
                    onChanged: (value) {
                      setState(() => _soundFeedbackEnabled = value);
                    },
                    activeThumbColor: const Color(0xFF1E4976),
                  ),
                  const SizedBox(height: 6),
                  _actionTile(
                    icon: Icons.face_retouching_natural,
                    title: 'Change avatar',
                    subtitle: 'Pick another profile avatar',
                    onTap: _showAvatarOptions,
                  ),
                  _actionTile(
                    icon: Icons.help_outline,
                    title: 'Help and feedback',
                    subtitle: 'Share your thoughts about the app',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback feature coming soon.')),
                      );
                    },
                  ),
                  _actionTile(
                    icon: Icons.info_outline,
                    title: 'About ReciteRight',
                    subtitle: 'Version and app details',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'ReciteRight',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF1E4976),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE04F5F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    super.dispose();
  }

  String _formatMemberSince(dynamic rawDate) {
    DateTime? parsed;

    if (rawDate is DateTime) {
      parsed = rawDate;
    } else {
      try {
        parsed = rawDate?.toDate();
      } catch (_) {
        parsed = null;
      }
    }

    if (parsed == null) {
      return 'recently';
    }

    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  Widget _profileInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E4976).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1E4976)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2A37),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E4976).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF1E4976), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2A37),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}


