import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tajweed_corrector/services/user_service.dart';
import 'package:tajweed_corrector/services/session_service.dart';
import 'ProfileScreen.dart';
import 'EnhancedReciteScreen.dart';
import 'TajweedLessonsScreen.dart';
import 'EnhancedProgressScreen.dart';
import 'SurahListScreen.dart';
import 'package:tajweed_corrector/screens/MistakesScreen.dart';
import 'package:tajweed_corrector/screens/MemorizationScreen.dart';
import 'package:tajweed_corrector/screens/AlphabetHomeScreen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen>
    with TickerProviderStateMixin {
  late UserService _userService;
  late SessionService _sessionService;
  late PageController _carouselController;

  // User Data
  String _userName = 'User';
  String? _userAvatar;
  bool _isDarkMode = false;

  // Progress Data
  int _currentStreak = 0;
  int _dailyGoalMinutes = 10;
  int _dailyMinutesCompleted = 6;
  String _nextSurah = 'Al-Baqarah';
  int _nextAyah = 5;
  String _lastRecitedTime = '2 days ago';
  int _userLevel = 2;
  String _userLevelName = 'Consistent Reciter';
  bool _isNewUser = false;
  int _carouselIndex = 0;

  // Today's Items Carousel
  final List<Map<String, dynamic>> _todayItems = [
    {
      'icon': Icons.auto_awesome_rounded,
      'title': 'Tajweed: Ghunnah',
      'action': 'lesson',
      'description': 'Master the nasalization rule',
      'duration': '3 min',
      'level': 'Beginner',
      'color': const Color(0xFF2E7D32),
      'bgColor': const Color(0xFFC8E6C9),
    },
    {
      'icon': Icons.autorenew_rounded,
      'title': 'Review Mistakes',
      'action': 'mistakes',
      'description': '3 words from yesterday',
      'duration': '5 min',
      'level': 'Intermediate',
      'color': const Color(0xFFE65100),
      'bgColor': const Color(0xFFFFE0B2),
    },
    {
      'icon': Icons.menu_book_rounded,
      'title': 'Memorize Today',
      'action': 'memorization',
      'description': 'Surah Al-Ikhlas (2 ayahs)',
      'duration': '7 min',
      'level': 'Advanced',
      'color': const Color(0xFF1565C0),
      'bgColor': const Color(0xFFBBDEFB),
    },
    {
      'icon': Icons.flash_on_rounded,
      'title': 'Fluency Check',
      'action': 'lesson',
      'description': 'Quick 1-minute practice',
      'duration': '1 min',
      'level': 'Beginner',
      'color': const Color(0xFF6A1B9A),
      'bgColor': const Color(0xFFE1BEE7),
    },
  ];

  @override
  void initState() {
    super.initState();
    _userService = UserService();
    _sessionService = SessionService();
    _carouselController = PageController(viewportFraction: 0.85);
    _loadUserData();
    _loadProgressData();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _userName = 'Guest');
        return;
      }

      final profile = await _userService.getUserProfile();
      String fullName = profile?['fullName'] ?? user.displayName ?? 'User';
      
      // Try multiple sources for avatar - check all possible field names
      String? avatarUrl;
      
      // 1. Try profile collection with all possible field names
      if (profile != null) {
        avatarUrl = (profile['profileImageUrl'] ?? 
                     profile['avatarUrl'] ?? 
                     profile['photoUrl'] ?? 
                     profile['photoURL'] ??
                     profile['avatar'])?.toString();
      }
      
      // 2. Try Firebase auth photo URL if no profile image
      if ((avatarUrl ?? '').isEmpty) {
        avatarUrl = user.photoURL;
      }
      
      // Clean up the URL - ensure it's not empty
      if (avatarUrl != null && avatarUrl.trim().isEmpty) {
        avatarUrl = null;
      }

      print('DEBUG: User avatar URL = $avatarUrl');
      print('DEBUG: User full name = $fullName');
      print('DEBUG: User profile data = $profile');

      setState(() {
        _userName = fullName;
        _userAvatar = avatarUrl;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadProgressData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final homeMetrics = await _sessionService.getHomeMetrics(userId: user.uid);
      setState(() {
        _currentStreak = homeMetrics.currentStreak;
        _dailyMinutesCompleted = homeMetrics.todayMinutes;
        if (homeMetrics.lastSessionDate != null &&
            homeMetrics.lastSessionDate!.isNotEmpty) {
          _lastRecitedTime = _formatDaysAgo(homeMetrics.lastSessionDate!);
        }
      });
    } catch (e) {
      print('Error loading progress data: $e');
    }
  }

  String _formatDaysAgo(String yyyyMmDd) {
    try {
      final sessionDate = DateTime.parse(yyyyMmDd);
      final diff = DateTime.now().difference(sessionDate).inDays;
      if (diff <= 0) return 'today';
      if (diff == 1) return '1 day ago';
      return '$diff days ago';
    } catch (_) {
      return 'recently';
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _changeSurah() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SurahListScreen()),
    ).then((value) {
      if (value != null && value is Map) {
        setState(() {
          _nextSurah = value['name'] ?? 'Al-Baqarah';
          _nextAyah = value['ayah'] ?? 5;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    final bgColor = isDark ? const Color(0xFF1a1a1a) : const Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER
              _buildHeader(isDark),

              // GAMIFIED DASHBOARD CONTENT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // State-Aware Hero Card
                    _buildHeroCard(isDark),

                    const SizedBox(height: 24),

                    // "Today for you" Carousel
                    _buildTodayCarousel(isDark),

                    const SizedBox(height: 20),

                    // Quick Actions Row
                    _buildQuickActionsRow(isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ========== COMPONENTS ==========

  Widget _buildAvatarImage() {
    // No avatar at all → fallback with initials
    if (_userAvatar == null || _userAvatar!.trim().isEmpty) {
      return _avatarFallback();
    }

    final String avatar = _userAvatar!.trim();

    // Decide based on scheme
    final bool isNetworkUrl =
        avatar.startsWith('http://') || avatar.startsWith('https://');

    if (isNetworkUrl) {
      print('Loading network avatar: $avatar');
      // Avatar from Firebase / web url
      return Image.network(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network avatar: $error');
          return _avatarFallback();
        },
      );
    } else {
      print('Loading asset avatar: $avatar');
      // Avatar from bundled assets (e.g assets/avatar.png)
      return Image.asset(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading asset avatar: $error');
          return _avatarFallback();
        },
      );
    }
  }

  Widget _avatarFallback() {
    final String initials = _extractInitials(_userName);

    return Container(
      color: const Color(0xFF2E5F8F),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _extractInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    // Get first letter of first and last name
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Widget _buildHeader(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A2A30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? const Color(0xFFB0B5C0) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App name + dark mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ReciteRight',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              GestureDetector(
                onTap: _toggleTheme,
                child: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: titleColor,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Greeting card — full card tappable to Profile
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assalam-o-Alaikum,',
                          style: TextStyle(
                            fontSize: 16,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Are you ready to recite?',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Avatar
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipOval(
                      child: _buildAvatarImage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildHeaderStatsRow(isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderStatsRow(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A2A30) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final progressPercent =
        (_dailyMinutesCompleted / _dailyGoalMinutes).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EnhancedProgressScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _buildHeaderStatTile(
                icon: Icons.timelapse_rounded,
                iconColor: const Color(0xFF1E4976),
                title: 'Today',
                value: '${(progressPercent * 100).toInt()}%',
                subtitle: '$_dailyMinutesCompleted/$_dailyGoalMinutes min',
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ),
            Expanded(
              child: _buildHeaderStatTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6F00),
                title: 'Streak',
                value: _currentStreak > 0 ? '$_currentStreak d' : '0 d',
                subtitle: _currentStreak > 0 ? 'Keep going' : 'Start today',
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ),
            Expanded(
              child: _buildHeaderStatTile(
                icon: Icons.verified_rounded,
                iconColor: const Color(0xFF2E5F8F),
                title: 'Level',
                value: '$_userLevel',
                subtitle: _userLevelName,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStatTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color textColor,
    required Color? subtextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: subtextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: subtextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: _isNewUser
            ? const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFF1E4976), Color(0xFF2E5F8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -25,
                      bottom: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 36,
                      bottom: 72,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 56,
                      bottom: 46,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isNewUser) ...[
            const Text(
              '🎉 Start Your Journey',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Begin your first recitation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join thousands learning Tajweed the fun way',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EnhancedReciteScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Begin Onboarding Lesson',
                  style: TextStyle(
                    color: Color(0xFF667EEA),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
                  ] else ...[
            const Text(
              '✨ Continue reciting',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_nextSurah $_nextAyah–${_nextAyah + 2}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last recited $_lastRecitedTime',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EnhancedReciteScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E4976),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                    minimumSize: const Size(0, 38),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStreakStrip(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final progressPercent =
    (_dailyMinutesCompleted / _dailyGoalMinutes).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const EnhancedProgressScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Daily Progress Ring
            Column(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildProgressRing(progressPercent, textColor!, isDark),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_dailyMinutesCompleted / $_dailyGoalMinutes min',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),

            // Streak
            Column(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 32,
                  color: Color(0xFFFF6F00),
                ),
                const SizedBox(height: 4),
                Text(
                  'Streak',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStreak > 0 ? '$_currentStreak days' : 'Start today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),

            // Level Badge
            Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4976).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: Color(0xFF1E4976),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level',
                        style: TextStyle(fontSize: 9, color: subtextColor),
                      ),
                      Text(
                        '$_userLevel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _userLevelName,
                  style: TextStyle(
                    fontSize: 10,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(double progress, Color textColor, bool isDark) {
    final progressColor = Color.lerp(
      const Color(0xFFE91E63),
      const Color(0xFF4CAF50),
      progress,
    )!;

    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCarousel(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today for you',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E4976),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() => _carouselIndex = index);
            },
            itemCount: _todayItems.length,
            itemBuilder: (context, index) {
              final item = _todayItems[index];
              return _buildCarouselCard(item, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(Map<String, dynamic> item, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (item['icon'] as IconData?) ?? Icons.auto_awesome_rounded,
                    size: 24,
                    color: item['color'] as Color,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item['bgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['duration'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item['color'],
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E4976),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['level'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item['color'],
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      final action =
                      (item['action'] ?? '').toString().toLowerCase();
                      final title =
                      (item['title'] ?? '').toString().toLowerCase();

                      if (action == 'mistakes' ||
                          title.contains('mistake')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MistakesScreen(),
                          ),
                        );
                        return;
                      }

                      if (action == 'memorization' ||
                          title.contains('memorize') ||
                          title.contains('memorization')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MemorizationScreen(),
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TajweedLessonsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item['color'],
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(bool isDark) {
    final quickActions = [
      {
        'label': 'Arabic\nAlphabet',
        'icon': Icons.grid_view_rounded,
        'color': const Color(0xFF1E4976)
      },
      {
        'label': 'Browse\nSurahs',
        'icon': Icons.library_books,
        'color': const Color(0xFF2196F3)
      },
      {
        'label': 'Tajweed\nLibrary',
        'icon': Icons.school,
        'color': const Color(0xFF673AB7)
      },
      {
        'label': 'My\nRecordings',
        'icon': Icons.mic,
        'color': const Color(0xFF009688)
      },
      {
        'label': 'My\nMistakes',
        'icon': Icons.bug_report,
        'color': const Color(0xFFE91E63)
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(quickActions.length, (index) {
          final action = quickActions[index];
          return Padding(
            padding: EdgeInsets.only(
                right: index < quickActions.length - 1 ? 12 : 0),
            child: _buildQuickActionPill(action, isDark),
          );
        }),
      ),
    );
  }

  Widget _buildQuickActionPill(Map<String, dynamic> action, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final color = action['color'] as Color;

    return GestureDetector(
      onTap: () {
        if ((action['label'] as String).contains('Alphabet')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AlphabetHomeScreen()),
          );
        } else if ((action['label'] as String).contains('Browse')) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SurahListScreen()));
        } else if ((action['label'] as String).contains('Tajweed')) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TajweedLessonsScreen()));
        } else if ((action['label'] as String).contains('Mistakes')) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const MistakesScreen()));
        } else if ((action['label'] as String).contains('Recordings')) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EnhancedProgressScreen()));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(action['icon'] as IconData, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              action['label'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E4976),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
      selectedItemColor: const Color(0xFF1E4976),
      unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Lessons'),
        BottomNavigationBarItem(
            icon: Icon(Icons.trending_up), label: 'Progress'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TajweedLessonsScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EnhancedProgressScreen()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
    );
  }
}

