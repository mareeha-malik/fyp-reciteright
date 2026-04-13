import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajweed_corrector/services/user_service.dart';
import 'package:tajweed_corrector/services/stats_service.dart';
import 'ProfileScreen.dart';
import 'EnhancedReciteScreen.dart';
import 'TajweedLessonsScreen.dart';
import 'EnhancedProgressScreen.dart';
import 'SurahListScreen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen>
    with TickerProviderStateMixin {
  late UserService _userService;
  late StatsService _statsService;
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
      'icon': '✨',
      'title': 'Tajweed: Ghunnah',
      'description': 'Master the nasalization rule',
      'duration': '3 min',
      'level': 'Beginner',
      'color': const Color(0xFF2E7D32),
      'bgColor': const Color(0xFFC8E6C9),
    },
    {
      'icon': '🔄',
      'title': 'Review Mistakes',
      'description': '3 words from yesterday',
      'duration': '5 min',
      'level': 'Intermediate',
      'color': const Color(0xFFE65100),
      'bgColor': const Color(0xFFFFE0B2),
    },
    {
      'icon': '📚',
      'title': 'Memorize Today',
      'description': 'Surah Al-Ikhlas (2 ayahs)',
      'duration': '7 min',
      'level': 'Advanced',
      'color': const Color(0xFF1565C0),
      'bgColor': const Color(0xFFBBDEFB),
    },
    {
      'icon': '⚡',
      'title': 'Fluency Check',
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
    _statsService = StatsService();
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
      String fullName =
          profile?['fullName'] ?? user.displayName ?? 'User';
      String? avatarUrl = profile?['avatarUrl'];

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
      final weeklyStats = await _statsService.getWeeklyStats();
      setState(() {
        _currentStreak = weeklyStats.longestStreak;
        _dailyMinutesCompleted = (weeklyStats.totalRecitations * 5).toInt();
      });
    } catch (e) {
      print('Error loading progress data: $e');
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
              // HEADER (Keep existing)
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

                    // Progress & Streak Strip
                    _buildProgressStreakStrip(isDark),

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

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);

    return Container(
      color: isDark ? const Color(0xFF2d2d2d) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ReciteRight',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleTheme,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF444444)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E4976),
                        border: Border.all(
                          color: textColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: _userAvatar != null
                          ? ClipOval(
                              child: Image.network(
                                _userAvatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      _userName.isNotEmpty
                                          ? _userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Assalam-o-Alaikum, $_userName 👋',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);

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
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
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
            const SizedBox(height: 8),
            Text(
              '$_nextSurah $_nextAyah–${_nextAyah + 2}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last recited $_lastRecitedTime',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
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
                  'Resume Recitation',
                  style: TextStyle(
                    color: Color(0xFF1E4976),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _changeSurah,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Change Surah',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStreakStrip(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final progressPercent = (_dailyMinutesCompleted / _dailyGoalMinutes).clamp(0.0, 1.0);

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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left: Daily Progress Ring
            Column(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildProgressRing(progressPercent, textColor, isDark),
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

            // Center: Streak
            Column(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 32)),
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

            // Right: Level Badge
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4976).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 20)),
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
          backgroundColor:
              isDark ? Colors.grey[800] : Colors.grey[300],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
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
              color: Colors.black.withOpacity(0.05),
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
                Text(
                  item['icon'],
                  style: const TextStyle(fontSize: 28),
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
                    color: item['color'].withOpacity(0.1),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const TajweedLessonsScreen()),
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
      {'label': 'Browse\nSurahs', 'icon': Icons.library_books, 'color': const Color(0xFF2196F3)},
      {'label': 'Tajweed\nLibrary', 'icon': Icons.school, 'color': const Color(0xFF673AB7)},
      {'label': 'My\nRecordings', 'icon': Icons.mic, 'color': const Color(0xFF009688)},
      {'label': 'My\nMistakes', 'icon': Icons.bug_report, 'color': const Color(0xFFE91E63)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          quickActions.length,
          (index) {
            final action = quickActions[index];
            return Padding(
              padding: EdgeInsets.only(right: index < quickActions.length - 1 ? 12 : 0),
              child: _buildQuickActionPill(action, isDark),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionPill(Map<String, dynamic> action, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final color = action['color'] as Color;

    return GestureDetector(
      onTap: () {
        // Handle quick action tap
        if (action['label'].contains('Browse')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SurahListScreen()),
          );
        } else if (action['label'].contains('Tajweed')) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const TajweedLessonsScreen()),
          );
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
            Icon(action['icon'], color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              action['label'],
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
        BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Progress'),
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
              MaterialPageRoute(
                  builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
    );
  }
}

