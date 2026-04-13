import 'package:flutter/material.dart';
import 'package:tajweed_corrector/models/gamification_models.dart';
import 'package:tajweed_corrector/services/gamification_service.dart';

/// State management for gamification metrics using ChangeNotifier
/// 
/// Usage:
/// ```dart
/// final provider = ChangeNotifierProvider(
///   create: (_) => GamificationNotifier(gamificationService),
/// );
/// ```
class GamificationNotifier extends ChangeNotifier {
  final GamificationService _service;
  
  // State
  HomeMetrics? _metrics;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  GamificationNotifier(this._service);
  
  // Getters
  HomeMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _metrics != null;
  
  // Convenience getters
  bool get isNewUser => _metrics?.isNewUser ?? true;
  int get dailyMinutes => _metrics?.dailyMinutes ?? 0;
  int get dailyGoal => _metrics?.dailyGoal ?? 10;
  double get dailyCompletion => _metrics?.dailyCompletion ?? 0.0;
  String get dailyStatus => _metrics?.dailyStatus ?? "not_started";
  
  int get currentStreak => _metrics?.currentStreak ?? 0;
  int get longestStreak => _metrics?.longestStreak ?? 0;
  
  int get userLevel => _metrics?.userLevel ?? 1;
  int get totalXp => _metrics?.totalXp ?? 0;
  double get percentToNextLevel => _metrics?.percentToNextLevel ?? 0.0;
  
  double get overallMemorization => _metrics?.overallMemorization ?? 0.0;
  List<Map<String, dynamic>> get topSurahs => _metrics?.topSurahs ?? [];
  
  /// Fetch home metrics for user
  /// 
  /// Args:
  /// - userId: The user ID to fetch metrics for
  /// - forceRefresh: Force fetch even if cache is fresh
  /// 
  /// Updates state and notifies listeners
  Future<void> fetchMetrics({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache
      if (!forceRefresh && 
          _lastRefresh != null && 
          DateTime.now().difference(_lastRefresh!).compareTo(_cacheDuration) < 0 &&
          _metrics != null) {
        print('✓ Using cached metrics (${DateTime.now().difference(_lastRefresh!).inSeconds}s old)');
        return;
      }
      
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      print('📊 Fetching home metrics for $userId...');
      final metrics = await _service.getHomeMetrics(userId: userId);
      
      _metrics = metrics;
      _lastRefresh = DateTime.now();
      _isLoading = false;
      _error = null;
      
      print('✅ Metrics fetched successfully');
      notifyListeners();
      
    } catch (e) {
      print('❌ Error fetching metrics: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Record a session and update metrics
  Future<void> recordSession({
    required String userId,
    required int surah,
    required int startAyah,
    required int endAyah,
    required double durationMinutes,
    required double accuracyScore,
    required String mode,
  }) async {
    try {
      print('📝 Recording session...');
      final result = await _service.recordSession(
        userId: userId,
        surah: surah,
        startAyah: startAyah,
        endAyah: endAyah,
        durationMinutes: durationMinutes,
        accuracyScore: accuracyScore,
        mode: mode,
      );
      
      final xpEarned = result['xpEarned'] as int? ?? 0;
      print('✅ Session recorded! +$xpEarned XP earned');
      
      // Refresh metrics after session
      await fetchMetrics(userId: userId, forceRefresh: true);
      
    } catch (e) {
      print('❌ Error recording session: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  /// Get the hero subtitle based on user state
  String getHeroSubtitle() {
    if (isNewUser) {
      return 'Start your first recitation today! 🎯';
    } else if (_metrics?.lastSession != null) {
      final lastSession = _metrics!.lastSession!;
      final surah = lastSession['surahName'] ?? 'Surah';
      final startAyah = lastSession['startAyah'] ?? 0;
      final endAyah = lastSession['endAyah'] ?? 0;
      return 'Continue $surah $startAyah–$endAyah';
    } else {
      return 'Resume your practice 📖';
    }
  }
  
  /// Get the hero icon based on user state
  String getHeroEmoji() {
    if (isNewUser) return '🌟';
    if (currentStreak > 7) return '🔥';
    if (userLevel >= 3) return '⭐';
    return '📖';
  }
  
  /// Get status message for daily progress
  String getDailyStatusMessage() {
    switch (dailyStatus) {
      case 'completed':
        return '🎉 Daily goal completed!';
      case 'in_progress':
        return '⏳ ${dailyGoal - dailyMinutes} minutes to go';
      case 'not_started':
      default:
        return '📍 Start your first recitation';
    }
  }
  
  /// Check if user should see onboarding
  bool shouldShowOnboarding() {
    return isNewUser && _metrics?.lastSession == null;
  }
  
  /// Check if user deserves celebration (level up, streak milestone, etc)
  Map<String, dynamic>? checkMilestone() {
    if (_metrics == null) return null;
    
    // Level up milestone
    if (_metrics!.percentToNextLevel > 95) {
      return {
        'type': 'almost_level_up',
        'title': 'Almost Level Up!',
        'message': 'Just ${(100 - percentToNextLevel).toStringAsFixed(0)}% more to Level ${userLevel + 1}',
        'emoji': '🚀'
      };
    }
    
    // 7-day streak
    if (currentStreak == 7) {
      return {
        'type': 'seven_day_streak',
        'title': '🔥 One Week Streak!',
        'message': 'Amazing dedication! Keep it up!',
        'emoji': '🔥'
      };
    }
    
    // Daily goal met
    if (dailyStatus == 'completed') {
      return {
        'type': 'daily_goal_met',
        'title': 'Daily Goal Met! 🎯',
        'message': 'Great work today!',
        'emoji': '🎯'
      };
    }
    
    return null;
  }
  
  /// Clear cache to force next fetch
  void clearCache() {
    _lastRefresh = null;
  }
  
  /// Reset all state
  void reset() {
    _metrics = null;
    _isLoading = false;
    _error = null;
    _lastRefresh = null;
    notifyListeners();
  }
}


// ════════════════════════════════════════════════════════════════════════════════
// EXAMPLE USAGE IN WIDGET
// ════════════════════════════════════════════════════════════════════════════════

/*
class HomeScreenExample extends StatefulWidget {
  final String userId;
  
  const HomeScreenExample({required this.userId});
  
  @override
  State<HomeScreenExample> createState() => _HomeScreenExampleState();
}

class _HomeScreenExampleState extends State<HomeScreenExample> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationNotifier>().fetchMetrics(userId: widget.userId);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GamificationNotifier>(
        builder: (context, notifier, _) {
          if (notifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (notifier.error != null) {
            return Center(
              child: Text('Error: ${notifier.error}'),
            );
          }
          
          if (!notifier.hasData) {
            return const Center(
              child: Text('No data available'),
            );
          }
          
          return ListView(
            children: [
              // Hero section
              buildHeroCard(context, notifier),
              
              // Daily progress
              buildDailyProgressCard(context, notifier),
              
              // Streak
              buildStreakPill(context, notifier),
              
              // Level
              buildLevelCard(context, notifier),
              
              // Top Surahs
              buildTopSurahsList(context, notifier),
              
              // Milestone celebration
              if (notifier.checkMilestone() != null)
                buildMilestoneCard(context, notifier.checkMilestone()!),
            ],
          );
        },
      ),
    );
  }
  
  Widget buildHeroCard(BuildContext context, GamificationNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              notifier.getHeroEmoji(),
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              notifier.getHeroSubtitle(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget buildDailyProgressCard(BuildContext context, GamificationNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: notifier.dailyCompletion,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text('${notifier.dailyMinutes}/${notifier.dailyGoal} minutes'),
            Text(notifier.getDailyStatusMessage()),
          ],
        ),
      ),
    );
  }
  
  Widget buildStreakPill(BuildContext context, GamificationNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Chip(
        avatar: const Icon(Icons.local_fire_department),
        label: Text('${notifier.currentStreak} day streak'),
        backgroundColor: notifier.currentStreak > 0 ? Colors.orange[100] : Colors.grey[200],
      ),
    );
  }
  
  Widget buildLevelCard(BuildContext context, GamificationNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Level ${notifier.userLevel}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: notifier.percentToNextLevel / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text('${notifier.totalXp} XP'),
          ],
        ),
      ),
    );
  }
  
  Widget buildTopSurahsList(BuildContext context, GamificationNotifier notifier) {
    if (notifier.topSurahs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Start reciting to track memorization progress'),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Top Memorized Surahs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifier.topSurahs.length,
          itemBuilder: (context, index) {
            final surah = notifier.topSurahs[index];
            return ListTile(
              title: Text(surah['surahName'] ?? 'Surah'),
              subtitle: Text('${surah['memorizedPercent']}% memorized'),
              trailing: Text('${surah['ayahCountMemorized']}/${surah['totalAyahs']}'),
            );
          },
        ),
      ],
    );
  }
  
  Widget buildMilestoneCard(BuildContext context, Map<String, dynamic> milestone) {
    return Card(
      color: Colors.green[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              milestone['emoji'] as String,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              milestone['title'] as String,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(milestone['message'] as String),
          ],
        ),
      ),
    );
  }
}
*/

