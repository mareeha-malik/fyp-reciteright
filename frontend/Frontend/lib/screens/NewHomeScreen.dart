import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajweed_corrector/services/user_service.dart';
import 'package:tajweed_corrector/services/stats_service.dart';
import 'package:tajweed_corrector/services/gamification_service.dart';
import 'package:tajweed_corrector/models/gamification_models.dart';
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
  late GamificationService _gamificationService;
  late AnimationController _progressAnimController;
  late AnimationController _carouselController;

  String _userName = 'User';
  String? _userAvatar;
  int _currentStreak = 0;
  int _dailyGoalMinutes = 10;
  int _dailyMinutesCompleted = 6;
  String _nextSurah = 'Al-Baqarah';
  int _nextAyah = 5;
  String _lastRecitedTime = '2 days ago';
  int _userLevel = 2;
  String _userLevelName = 'Consistent Reciter';
  bool _isDarkMode = false;
  bool _isNewUser = false;
  
  // Gamification metrics
  HomeMetrics? _homeMetrics;
  bool _gamificationLoading = true;
  
  // Progress tracking
  double _todayProgress = 0.0;
  double _weekProgress = 0.0;
  String _todayLessonRule = 'Tajweed: Ghunnah';
  String _todayLessonDescription = 'Master the nasalization rule';

  // Today's lesson carousel items
  List<Map<String, dynamic>> _todayItems = [
    {
      'icon': '✨',
      'title': 'Tajweed: Ghunnah',
      'description': 'Master the nasalization rule',
      'duration': '3 min',
      'level': 'Beginner',
      'color': const Color(0xFF2E7D32),
    },
    {
      'icon': '🔄',
      'title': 'Review Mistakes',
      'description': '3 words from yesterday',
      'duration': '5 min',
      'level': 'Intermediate',
      'color': const Color(0xFFE65100),
    },
    {
      'icon': '📚',
      'title': 'Memorize Today',
      'description': 'Surah Al-Ikhlas (2 ayahs)',
      'duration': '7 min',
      'level': 'Advanced',
      'color': const Color(0xFF1565C0),
    },
    {
      'icon': '⚡',
      'title': 'Fluency Check',
      'description': 'Quick 1-minute practice',
      'duration': '1 min',
      'level': 'Beginner',
      'color': const Color(0xFF6A1B9A),
    },
  ];

  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _userService = UserService();
    _statsService = StatsService();
    _gamificationService = GamificationService();
    _progressAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _carouselController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _loadUserData();
    _loadProgressData();
    _loadGamificationMetrics();
    _progressAnimController.forward();
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
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
        _todayProgress = (weeklyStats.totalRecitations * 5).toDouble(); // Estimate: 5 min per recitation
        _weekProgress = (weeklyStats.averageAccuracy); // Use average accuracy as week progress
      });
    } catch (e) {
      print('Error loading progress data: $e');
    }
  }

  Future<void> _loadGamificationMetrics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final metrics = await _gamificationService.getHomeMetrics(userId: user.uid);
        
        // Map level number to title
        final levelTitles = {
          1: 'Starting Scholar',
          2: 'Consistent Reciter',
          3: 'Dedicated Learner',
          4: 'Tajweed Student',
          5: 'Quranic Enthusiast',
          6: 'Hafiz-in-Training',
          7: 'Advanced Reciter',
          8: 'Surah Master',
          9: 'Quran Warrior',
          10: 'Hafiz al-Quran',
        };
        
        setState(() {
          _homeMetrics = metrics;
          _currentStreak = metrics.currentStreak;
          _userLevel = metrics.userLevel;
          _userLevelName = levelTitles[metrics.userLevel] ?? 'Scholar';
          _dailyMinutesCompleted = metrics.dailyMinutes;
          _dailyGoalMinutes = metrics.dailyGoal;
          _todayProgress = (metrics.dailyMinutes * 1.0);
          _weekProgress = metrics.weekMinutes.toDouble();
          _isNewUser = metrics.isNewUser;
          _gamificationLoading = false;
        });
        print('✅ Gamification metrics loaded: Level ${metrics.userLevel} (${levelTitles[metrics.userLevel]}), ${metrics.currentStreak} day streak, ${metrics.dailyMinutes}/${metrics.dailyGoal} min today');
      }
    } catch (e) {
      print('⚠️ Error loading gamification metrics: $e');
      setState(() => _gamificationLoading = false);
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

  // TODAY'S CAROUSEL - Tajweed lessons and activities
  Widget _buildTodayCarousel(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today for You',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: PageView.builder(
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
            },
            itemCount: _todayItems.length,
            itemBuilder: (context, index) {
              final item = _todayItems[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TajweedLessonsScreen(),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.1),
                    border: Border.all(
                      color: (item['color'] as Color).withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['icon'] as String,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: item['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['description'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: (item['color'] as Color).withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        item['duration'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: (item['color'] as Color).withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Carousel dots
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _todayItems.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentCarouselIndex == index
                      ? const Color(0xFF1E4976)
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // QUICK ACTIONS - Grid of common actions
  Widget _buildQuickActionsRow(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);

    final actions = [
      {
        'icon': Icons.school,
        'label': 'Learn\nTajweed',
        'color': const Color(0xFF673AB7),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TajweedLessonsScreen()),
          );
        },
      },
      {
        'icon': Icons.mic,
        'label': 'Start\nRecitation',
        'color': const Color(0xFF009688),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EnhancedReciteScreen()),
          );
        },
      },
      {
        'icon': Icons.trending_up,
        'label': 'View\nProgress',
        'color': const Color(0xFF2196F3),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EnhancedProgressScreen()),
          );
        },
      },
      {
        'icon': Icons.library_books,
        'label': 'Browse\nSurahs',
        'color': const Color(0xFFFF6F00),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SurahListScreen()),
          );
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: action['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (action['color'] as Color).withOpacity(0.2),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    size: 24,
                    color: action['color'] as Color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  // HEADER - Keep existing design
  Widget _buildHeader(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      color: isDark ? const Color(0xFF2d2d2d) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Logo + Avatar + Theme toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // App name
              Text(
                'ReciteRight',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              // Avatar + Theme Toggle
              Row(
                children: [
                  // Theme toggle
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

                  // Profile Avatar
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

          // Greeting text
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

  // STATE-AWARE HERO CARD
  Widget _buildHeroCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);

    return Container(
      decoration: BoxDecoration(
        gradient: _isNewUser
            ? LinearGradient(
                colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [const Color(0xFF1E4976), const Color(0xFF2E5F8F)],
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

  // PROGRESS & STREAK STRIP
  Widget _buildProgressStreakStrip(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2d2d2d) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E4976);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Use gamification metrics if available
    final dailyMinutes = _homeMetrics?.dailyMinutes ?? _dailyMinutesCompleted;
    final dailyGoal = _homeMetrics?.dailyGoal ?? _dailyGoalMinutes;
    final progressPercent = (dailyMinutes / dailyGoal).clamp(0.0, 1.0);

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
                  child: _buildProgressRing(
                    progressPercent,
                    textColor,
                    isDark,
                  ),
                ),
                const SizedBox(height: 8),
                 Text(
                   '$dailyMinutes / $dailyGoal min',
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
                Text(
                  '🔥',
                  style: TextStyle(fontSize: 32, height: 1),
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
                  _currentStreak > 0
                      ? '$_currentStreak days'
                      : 'Start today',
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
                      Text(
                        '⭐',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level',
                        style: TextStyle(
                          fontSize: 9,
                          color: subtextColor,
                        ),
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

  // Animated Progress Ring
  Widget _buildProgressRing(
      double progress, Color textColor, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              width: 3,
            ),
          ),
        ),
        // Progress circle
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.lerp(
              const Color(0xFFE91E63),
              const Color(0xFF4CAF50),
              progress,
            )!,
          ),
          backgroundColor: Colors.transparent,
        ),
        // Center text
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

  Widget _buildProgressRow(Color textColor, Color cardColor,
      Color? subtextColor, bool isDark) {
    return Row(
      children: [
        // Daily Goal Card
        Expanded(
          child: _buildProgressCard(
            title: 'Daily Goal',
            value: '${_todayProgress.toInt()}',
            unit: 'min',
            target: _dailyGoalMinutes,
            icon: Icons.flag,
            color: const Color(0xFF4CAF50),
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EnhancedProgressScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),

        // Weekly Progress Card
        Expanded(
          child: _buildProgressCard(
            title: 'This Week',
            value: '${_weekProgress.toInt()}',
            unit: '%',
            target: 100,
            icon: Icons.trending_up,
            color: const Color(0xFF2196F3),
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EnhancedProgressScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String value,
    required String unit,
    required int target,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color? subtextColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon & Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),

            // Value
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: int.parse(value) / target,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLessonCard(Color textColor, Color cardColor,
      Color? subtextColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  size: 20,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Lesson",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rule name
          Text(
            _todayLessonRule,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            _todayLessonDescription,
            style: TextStyle(
              fontSize: 13,
              color: subtextColor,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Learn & Practice Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TajweedLessonsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Learn & Practice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(Color textColor, Color cardColor,
      Color? subtextColor, bool isDark) {
    final quickActions = [
      {
        'label': 'Tajweed\nLessons',
        'icon': Icons.school,
        'color': const Color(0xFF673AB7),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const TajweedLessonsScreen()),
          );
        },
      },
      {
        'label': 'Practice\nwith Qari',
        'icon': Icons.mic,
        'color': const Color(0xFF009688),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const EnhancedReciteScreen()),
          );
        },
      },
      {
        'label': 'Review\nMistakes',
        'icon': Icons.bug_report,
        'color': const Color(0xFFE91E63),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const EnhancedProgressScreen()),
          );
        },
      },
      {
        'label': 'Browse\nSurahs',
        'icon': Icons.library_books,
        'color': const Color(0xFF2196F3),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SurahListScreen()),
          );
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: quickActions.length,
      itemBuilder: (context, index) {
        final action = quickActions[index];
        return _buildQuickActionTile(
          label: action['label'] as String,
          icon: action['icon'] as IconData,
          color: action['color'] as Color,
          onTap: action['onTap'] as VoidCallback,
          cardColor: cardColor,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildQuickActionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Color cardColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(Color textColor, Color cardColor,
      Color? subtextColor, bool isDark) {
    final recentActivities = [
      {
        'title': 'Yesterday: Surah Al-Mulk',
        'subtitle': '5 min',
        'icon': Icons.history,
      },
      {
        'title': 'Last Mistake Review',
        'subtitle': '2 min',
        'icon': Icons.edit,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Where You Left Off',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        ...recentActivities.map((activity) {
          return GestureDetector(
            onTap: () {
              // Navigate to the activity
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EnhancedReciteScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    activity['icon'] as IconData,
                    size: 20,
                    color: const Color(0xFF1E4976),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: subtextColor,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
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
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school),
          label: 'Lessons',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            // Home (already here)
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

