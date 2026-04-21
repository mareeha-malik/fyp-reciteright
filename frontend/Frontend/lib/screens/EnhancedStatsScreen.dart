import 'package:flutter/material.dart';
import 'package:tajweed_corrector/services/stats_service.dart';
import 'package:tajweed_corrector/widgets/index.dart';

class EnhancedStatsScreen extends StatefulWidget {
  const EnhancedStatsScreen({super.key});

  @override
  State<EnhancedStatsScreen> createState() => _EnhancedStatsScreenState();
}

class _EnhancedStatsScreenState extends State<EnhancedStatsScreen> {
  final StatsService _statsService = StatsService();
  late WeeklyStats _weeklyStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _statsService.getWeeklyStats();
      
      // Use real data if available, otherwise use hardcoded sample data
      WeeklyStats displayStats = stats;
      
      print('📊 Stats loaded: totalRecitations=${stats.totalRecitations}');
      
      if (stats.totalRecitations == 0) {
        print('📝 No real stats available, using sample data for demonstration');
        // Hardcoded sample data for demonstration
        displayStats = WeeklyStats(
          accuracyByDay: [78.5, 85.0, 92.5, 88.0, 91.0, 95.5, 89.0],
          recitationsByDay: [3, 5, 4, 6, 2, 4, 5],
          averageAccuracy: 88.6,
          totalRecitations: 29,
          perfectRecitations: 18,
          longestStreak: 7,
          weekStart: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
          weekEnd: DateTime.now().add(Duration(days: 7 - DateTime.now().weekday)),
        );
      } else {
        print('✅ Real stats loaded: ${displayStats.totalRecitations} recitations');
      }
      
      if (mounted) {
        setState(() {
          _weeklyStats = displayStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Your Progress'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF1E4976).withValues(alpha: 0.3),
      ),
      body: _isLoading
          ? Center(
              child: SkeletonLoader(
                itemCount: 4,
                itemHeight: 100,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF1E4976),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Stats Cards
                    _buildStatsRow(),
                    const SizedBox(height: 24),

                    // Weekly Accuracy Chart
                    _buildAccuracyChart(),
                    const SizedBox(height: 24),

                    // Weekly Activity Chart
                    _buildActivityChart(),
                    const SizedBox(height: 24),

                    // Performance Insights
                    _buildInsights(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FadeInWidget(
          delay: const Duration(milliseconds: 100),
          child: StatCard(
            label: 'This Week',
            value: _weeklyStats.totalRecitations.toString(),
            icon: Icons.mic,
            iconColor: const Color(0xFF1E4976),
          ),
        ),
        FadeInWidget(
          delay: const Duration(milliseconds: 200),
          child: StatCard(
            label: 'Average',
            value: '${_weeklyStats.averageAccuracy.toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            iconColor: const Color(0xFF26C281),
          ),
        ),
        FadeInWidget(
          delay: const Duration(milliseconds: 300),
          child: StatCard(
            label: 'Perfect',
            value: _weeklyStats.perfectRecitations.toString(),
            icon: Icons.star,
            iconColor: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxAccuracy = _weeklyStats.accuracyByDay.isEmpty
        ? 100.0
        : _weeklyStats.accuracyByDay.reduce((a, b) => a > b ? a : b).toDouble();

    return EnhancedCard(
      gradientColors: [Colors.white, Colors.white],
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accuracy This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E4976),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (index) {
                  final value = _weeklyStats.accuracyByDay[index];
                  final height = (value / (maxAccuracy > 0 ? maxAccuracy : 100)) * 85;
                  final isToday = DateTime.now().weekday - 1 == index;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${value.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: height,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF1E4976)
                                : const Color(0xFF2E5F8F).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? const Color(0xFF1E4976)
                                : Colors.grey[600],
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxRecitations = _weeklyStats.recitationsByDay.isEmpty
        ? 5
        : _weeklyStats.recitationsByDay.reduce((a, b) => a > b ? a : b);

    return EnhancedCard(
      gradientColors: [Colors.white, Colors.white],
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E4976),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (index) {
                  final value = _weeklyStats.recitationsByDay[index];
                  final height =
                      (value / (maxRecitations > 0 ? maxRecitations : 5)) * 85;
                  final isToday = DateTime.now().weekday - 1 == index;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: height,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF26C281)
                                : const Color(0xFF26C281).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? const Color(0xFF26C281)
                                : Colors.grey[600],
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    return EnhancedCard(
      gradientColors: [Colors.white, Colors.white],
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week\'s Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E4976),
            ),
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            icon: Icons.local_fire_department,
            label: 'Current Streak',
            value: '${_weeklyStats.longestStreak} days',
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            icon: Icons.check_circle,
            label: 'Perfect Recitations',
            value: '${_weeklyStats.perfectRecitations} out of ${_weeklyStats.totalRecitations}',
            color: const Color(0xFF26C281),
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            icon: Icons.show_chart,
            label: 'Average Accuracy',
            value: '${_weeklyStats.averageAccuracy.toStringAsFixed(1)}%',
            color: const Color(0xFF1E4976),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4976),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
