import 'package:flutter/material.dart';
import 'package:tajweed_corrector/services/gamification_service.dart';
import 'package:tajweed_corrector/models/gamification_models.dart';

class RealProgressScreen extends StatefulWidget {
  const RealProgressScreen({super.key});

  @override
  State<RealProgressScreen> createState() => _RealProgressScreenState();
}

class _RealProgressScreenState extends State<RealProgressScreen> {
  final GamificationService _gamificationService = GamificationService();
  
  late Future<HomeMetrics> _homeMetricsFuture;
  late Future<StreakInfo> _streakFuture;
  late Future<Map<String, dynamic>> _weekSummaryFuture;
  late Future<Map<String, dynamic>> _memorizationFuture;

  String _userId = "user_test_123"; // Replace with actual user ID
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    _homeMetricsFuture = _gamificationService.getHomeMetrics(userId: _userId);
    _streakFuture = _gamificationService.getStreakInfo(userId: _userId);
    
    final today = DateTime.now();
    final weekStart = _getWeekStart(today);
    _weekSummaryFuture = _gamificationService.getWeekSummary(
      userId: _userId,
      weekStartDate: _formatDate(weekStart),
    );
    
    _memorizationFuture = _gamificationService.getMemorizationProgress(userId: _userId);

    Future.wait([
      _homeMetricsFuture,
      _streakFuture,
      _weekSummaryFuture,
      _memorizationFuture,
    ]).then((_) {
      setState(() => isLoading = false);
    }).catchError((e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error loading progress: $e";
      });
    });
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  DateTime _getWeekStart(DateTime date) {
    // Monday is weekday 1
    final daysUntilMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysUntilMonday));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Progress & Streak'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Progress Ring
                        FutureBuilder<HomeMetrics>(
                          future: _homeMetricsFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final metrics = snapshot.data!;
                            return _buildDailyProgressCard(metrics);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Streak Section
                        FutureBuilder<StreakInfo>(
                          future: _streakFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final streak = snapshot.data!;
                            return _buildStreakSection(streak);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Level & XP
                        FutureBuilder<HomeMetrics>(
                          future: _homeMetricsFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final metrics = snapshot.data!;
                            return _buildLevelCard(metrics);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Weekly Summary
                        FutureBuilder<Map<String, dynamic>>(
                          future: _weekSummaryFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final week = snapshot.data!;
                            return _buildWeeklySummaryCard(week);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Memorization Progress
                        FutureBuilder<Map<String, dynamic>>(
                          future: _memorizationFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final memo = snapshot.data!;
                            return _buildMemorizationCard(memo);
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyProgressCard(HomeMetrics metrics) {
    final dailyMinutes = metrics.dailyMinutes;
    final dailyGoal = metrics.dailyGoal;
    final completion = metrics.dailyCompletion;
    final status = metrics.dailyStatus;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    status == "completed"
                        ? "Completed ✅"
                        : status == "in_progress"
                            ? "In Progress 🔄"
                            : "Not Started",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: status == "completed"
                      ? Colors.green
                      : status == "in_progress"
                          ? Colors.blue
                          : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                height: 150,
                width: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completion,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completion >= 1.0 ? Colors.green : Colors.blue,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dailyMinutes',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E4976),
                          ),
                        ),
                        const Text(
                          'minutes',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Goal: $dailyGoal minutes'),
                Text('${(completion * 100).toStringAsFixed(0)}% complete'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakSection(StreakInfo streak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Streak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                title: 'Current Streak',
                value: streak.currentStreakDays,
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6F00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStreakCard(
                title: 'Longest Streak',
                value: streak.longestStreakDays,
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF9A825),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakCard({
    required String title,
    required int value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E4976),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            Text(
              'days',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(HomeMetrics metrics) {
    final level = metrics.userLevel;
    final xp = metrics.totalXp;
    final percentToNext = metrics.percentToNextLevel;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Level & XP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4976),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level $level',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('$xp XP', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentToNext / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${percentToNext.toStringAsFixed(1)}% to next level',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard(Map<String, dynamic> week) {
    final totalMinutes = (week['totalMinutes'] as num?)?.toInt() ?? 0;
    final daysActive = (week['daysActive'] as num?)?.toInt() ?? 0;
    final avgPerDay = (week['averageMinutesPerDay'] as num?)?.toDouble() ?? 0.0;
    final dailyBreakdown = (week['dailyBreakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeekStatItem('Total', '$totalMinutes min'),
                _buildWeekStatItem('Days Active', '$daysActive / 7'),
                _buildWeekStatItem('Avg / Day', '${avgPerDay.toStringAsFixed(1)} min'),
              ],
            ),
            const SizedBox(height: 20),
            // Daily breakdown chart
            const Text('Daily Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: _buildWeekChart(dailyBreakdown),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E4976),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildWeekChart(List<Map<String, dynamic>> dailyBreakdown) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxMinutes = dailyBreakdown.isEmpty
        ? 10.0
        : (dailyBreakdown.map((d) => (d['minutes'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        7,
        (index) {
          final dayData =
              index < dailyBreakdown.length ? dailyBreakdown[index] : <String, dynamic>{};
          final minutes = (dayData['minutes'] as num?)?.toDouble() ?? 0.0;
          final height = (minutes / (maxMinutes > 0 ? maxMinutes : 10)) * 120;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: height,
                decoration: BoxDecoration(
                  color: minutes > 0 ? Colors.blue : Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 4),
              Text(days[index], style: const TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemorizationCard(Map<String, dynamic> memo) {
    final overallPercent = (memo['overallPercent'] as num?)?.toDouble() ?? 0.0;
    final topSurahs = (memo['topSurahs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Memorization Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${overallPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E4976),
                        ),
                      ),
                      const Text('Overall', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overallPercent / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            if (topSurahs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Top Memorized Surahs', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...topSurahs.take(3).map((surah) {
                final surahName = surah['surahName'] ?? 'Surah';
                final memorizedPercent = (surah['memorizedPercent'] as num?)?.toDouble() ?? 0.0;
                final ayahCount = surah['ayahCountMemorized'] ?? 0;
                final totalAyahs = surah['totalAyahs'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(surahName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('$ayahCount/$totalAyahs ayahs'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: memorizedPercent / 100,
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}


