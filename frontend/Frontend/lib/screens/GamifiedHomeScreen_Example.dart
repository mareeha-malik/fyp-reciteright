/// Example Integration of Gamification into ReciteRight Home Screen
/// 
/// This file shows how to use the gamification metrics in actual UI widgets
/// Adapt these examples to match your existing home screen design

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tajweed_corrector/models/gamification_models.dart';
import 'package:tajweed_corrector/services/gamification_service.dart';
import 'package:tajweed_corrector/services/gamification_notifier.dart';

// ════════════════════════════════════════════════════════════════════════════════
// 1. HERO SECTION - "Start Your Recitation" or "Continue Al-Baqarah"
// ════════════════════════════════════════════════════════════════════════════════

class HomeHeroCard extends StatelessWidget {
  final GamificationNotifier notifier;

  const HomeHeroCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notifier.getHeroEmoji(),
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back!' if !notifier.isNewUser else 'Start Learning Quran',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notifier.getHeroSubtitle(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to recitation screen
              // Navigator.push(context, MaterialPageRoute(builder: (_) => RecitationScreen()));
            },
            icon: const Icon(Icons.mic),
            label: const Text('Start Recitation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 2. DAILY PROGRESS RING with percentage
// ════════════════════════════════════════════════════════════════════════════════

class DailyProgressRing extends StatelessWidget {
  final GamificationNotifier notifier;

  const DailyProgressRing({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            // Progress Ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: notifier.dailyCompletion,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      notifier.dailyStatus == 'completed'
                          ? Colors.green
                          : Colors.blue,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(notifier.dailyCompletion * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notifier.dailyMinutes}/${notifier.dailyGoal} min',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Status message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: notifier.dailyStatus == 'completed'
                    ? Colors.green[50]
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notifier.getDailyStatusMessage(),
                style: TextStyle(
                  color: notifier.dailyStatus == 'completed'
                      ? Colors.green[700]
                      : Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 3. STREAK PILL with fire icon
// ════════════════════════════════════════════════════════════════════════════════

class StreakPill extends StatelessWidget {
  final GamificationNotifier notifier;

  const StreakPill({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final hasStreak = notifier.currentStreak > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        children: [
          // Current streak
          Chip(
            avatar: Icon(
              Icons.local_fire_department,
              color: hasStreak ? Colors.orange : Colors.grey,
            ),
            label: Text('${notifier.currentStreak} day streak'),
            backgroundColor: hasStreak ? Colors.orange[50] : Colors.grey[100],
            side: BorderSide(
              color: hasStreak ? Colors.orange : Colors.grey[300]!,
            ),
          ),
          // Longest streak (as achievement)
          if (notifier.longestStreak > 0)
            Chip(
              avatar: const Icon(Icons.emoji_events, color: Colors.amber),
              label: Text('Best: ${notifier.longestStreak} days'),
              backgroundColor: Colors.amber[50],
              side: BorderSide(color: Colors.amber[300]!),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 4. LEVEL & XP CARD
// ════════════════════════════════════════════════════════════════════════════════

class LevelCard extends StatelessWidget {
  final GamificationNotifier notifier;

  const LevelCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${notifier.userLevel}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consistent Reciter', // Get from LEVEL_TITLES
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                // XP badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star, color: Colors.purple, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        '${notifier.totalXp} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress to next level
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: notifier.percentToNextLevel / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${notifier.percentToNextLevel.toStringAsFixed(1)}% to Level ${notifier.userLevel + 1}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 5. WEEKLY CHART
// ════════════════════════════════════════════════════════════════════════════════

class WeeklyChart extends StatelessWidget {
  final GamificationNotifier notifier;

  const WeeklyChart({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final dailyBreakdown = notifier.metrics?.week['dailyBreakdown'] ?? [];

    // Convert to chart data
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < dailyBreakdown.length; i++) {
      final daily = dailyBreakdown[i] as Map;
      final minutes = (daily['minutes'] as num?)?.toDouble() ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: minutes,
              color: minutes > 0 ? Colors.blue : Colors.grey[200],
              width: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${notifier.weekMinutes} minutes • ${notifier.weekDaysActive} days active',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Text(
                            weekDays[value.toInt() % 7],
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: _getTitleWidget,
                      ),
                    ),
                  ),
                  maxY: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _getTitleWidget(double value, TitleMeta meta) {
    return Text(
      '${value.toInt()}',
      style: const TextStyle(fontSize: 12),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 6. TOP SURAHS - Memorization Progress
// ════════════════════════════════════════════════════════════════════════════════

class TopSurahsList extends StatelessWidget {
  final GamificationNotifier notifier;

  const TopSurahsList({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final topSurahs = notifier.topSurahs;

    if (topSurahs.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.book, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Start reciting to track memorization',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Memorized Surahs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${notifier.overallMemorization.toStringAsFixed(1)}% total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...topSurahs.asMap().entries.map((entry) {
              final surah = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                surah['surahName'] ?? 'Surah',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${surah['ayahCountMemorized']}/${surah['totalAyahs']} ayahs',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${surah['memorizedPercent']}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (surah['memorizedPercent'] as num) / 100,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 7. MILESTONE CELEBRATION DIALOG
// ════════════════════════════════════════════════════════════════════════════════

class MilestoneDialog extends StatelessWidget {
  final Map<String, dynamic> milestone;

  const MilestoneDialog({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              milestone['emoji'] as String? ?? '🎉',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              milestone['title'] as String? ?? 'Achievement Unlocked!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              milestone['message'] as String? ?? 'Great job!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 8. COMPLETE HOME SCREEN EXAMPLE
// ════════════════════════════════════════════════════════════════════════════════

class GamifiedHomeScreenExample extends StatefulWidget {
  final String userId;

  const GamifiedHomeScreenExample({required this.userId});

  @override
  State<GamifiedHomeScreenExample> createState() =>
      _GamifiedHomeScreenExampleState();
}

class _GamifiedHomeScreenExampleState extends State<GamifiedHomeScreenExample> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch metrics when screen loads
      context
          .read<GamificationNotifier>()
          .fetchMetrics(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReciteRight'),
        centerTitle: true,
      ),
      body: Consumer<GamificationNotifier>(
        builder: (context, notifier, _) {
          if (notifier.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (notifier.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${notifier.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      notifier.fetchMetrics(
                        userId: widget.userId,
                        forceRefresh: true,
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!notifier.hasData) {
            return const Center(
              child: Text('No data available'),
            );
          }

          // Check for milestone and show celebration
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final milestone = notifier.checkMilestone();
            if (milestone != null) {
              showDialog(
                context: context,
                builder: (_) => MilestoneDialog(milestone: milestone),
              );
            }
          });

          return RefreshIndicator(
            onRefresh: () => notifier.fetchMetrics(
              userId: widget.userId,
              forceRefresh: true,
            ),
            child: ListView(
              children: [
                // Hero section
                HomeHeroCard(notifier: notifier),

                // Daily progress ring
                DailyProgressRing(notifier: notifier),

                // Streak pill
                StreakPill(notifier: notifier),

                // Level & XP
                LevelCard(notifier: notifier),

                // Weekly chart
                WeeklyChart(notifier: notifier),

                // Top surahs
                TopSurahsList(notifier: notifier),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Usage in main.dart:
// 
// runApp(
//   MultiProvider(
//     providers: [
//       Provider(create: (_) => GamificationService()),
//       ChangeNotifierProvider(
//         create: (context) => GamificationNotifier(
//           context.read<GamificationService>(),
//         ),
//       ),
//     ],
//     child: MyApp(),
//   ),
// );
//
// Then in your home screen:
// home: GamifiedHomeScreenExample(userId: "user123"),
// ════════════════════════════════════════════════════════════════════════════════

