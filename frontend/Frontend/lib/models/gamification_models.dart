import 'package:json_annotation/json_annotation.dart';

part 'gamification_models.g.dart';

/// User profile with gamification metadata
@JsonSerializable()
class UserProfile {
  final String id;
  final String name;
  final String email;
  final DateTime joinedAt;
  final int dailyGoalMinutes;
  final int dailyGoalAyahs;
  final int level;
  final int xp;
  final int longestStreak;
  final String? avatarUrl;
  final int timezoneOffset; // Minutes offset from UTC

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.joinedAt,
    this.dailyGoalMinutes = 10,
    this.dailyGoalAyahs = 0,
    this.level = 1,
    this.xp = 0,
    this.longestStreak = 0,
    this.avatarUrl,
    this.timezoneOffset = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

/// Single recitation session
@JsonSerializable()
class Session {
  final String id;
  final String userId;
  final int surah;
  final int startAyah;
  final int endAyah;
  final double durationMinutes;
  final String date; // UTC date (YYYY-MM-DD)
  final double accuracyScore; // 0-100
  final String mode; // "recitation" | "tajweed_lesson" | "review"
  final DateTime createdAt;
  final int xpEarned;

  Session({
    required this.id,
    required this.userId,
    required this.surah,
    required this.startAyah,
    required this.endAyah,
    required this.durationMinutes,
    required this.date,
    required this.accuracyScore,
    required this.mode,
    required this.createdAt,
    this.xpEarned = 0,
  });

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  Map<String, dynamic> toJson() => _$SessionToJson(this);
}

/// Memorization progress for a surah
@JsonSerializable()
class MemorizationProgress {
  final String userId;
  final int surah;
  final int ayahCountMemorized;
  final DateTime? lastReviewedAt;
  final Map<int, int> highAccuracySessions; // {ayahNum: count}

  MemorizationProgress({
    required this.userId,
    required this.surah,
    this.ayahCountMemorized = 0,
    this.lastReviewedAt,
    this.highAccuracySessions = const {},
  });

  factory MemorizationProgress.fromJson(Map<String, dynamic> json) =>
      _$MemorizationProgressFromJson(json);

  Map<String, dynamic> toJson() => _$MemorizationProgressToJson(this);
}

/// Daily progress metrics
@JsonSerializable()
class DailyProgress {
  final String date; // YYYY-MM-DD
  final int totalMinutes;
  final int sessionsCount;
  final double accuracyAverage;
  final String status; // "not_started" | "in_progress" | "completed"

  DailyProgress({
    required this.date,
    this.totalMinutes = 0,
    this.sessionsCount = 0,
    this.accuracyAverage = 0.0,
    this.status = "not_started",
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) =>
      _$DailyProgressFromJson(json);

  Map<String, dynamic> toJson() => _$DailyProgressToJson(this);
}

/// Streak information
@JsonSerializable()
class StreakInfo {
  final int currentStreakDays;
  final int longestStreakDays;
  final String? lastSessionDate; // YYYY-MM-DD

  StreakInfo({
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.lastSessionDate,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) =>
      _$StreakInfoFromJson(json);

  Map<String, dynamic> toJson() => _$StreakInfoToJson(this);
}

/// Level and XP information
@JsonSerializable()
class LevelInfo {
  final int levelNumber;
  final int xpTotal;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final double percentToNext; // 0-100

  LevelInfo({
    required this.levelNumber,
    required this.xpTotal,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.percentToNext,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) =>
      _$LevelInfoFromJson(json);

  Map<String, dynamic> toJson() => _$LevelInfoToJson(this);
}

/// Top memorized surah
@JsonSerializable()
class TopSurah {
  final int surahNumber;
  final String surahName;
  final double memorizedPercent;
  final int ayahCountMemorized;
  final int totalAyahs;

  TopSurah({
    required this.surahNumber,
    required this.surahName,
    required this.memorizedPercent,
    required this.ayahCountMemorized,
    required this.totalAyahs,
  });

  factory TopSurah.fromJson(Map<String, dynamic> json) =>
      _$TopSurahFromJson(json);

  Map<String, dynamic> toJson() => _$TopSurahToJson(this);
}

/// Aggregated metrics for home screen
@JsonSerializable()
class HomeMetrics {
  final bool isNewUser;
  final Map<String, dynamic> daily;
  final Map<String, dynamic> streak;
  final Map<String, dynamic> week;
  final Map<String, dynamic> level;
  final Map<String, dynamic> memorization;
  final Map<String, dynamic>? lastSession;

  HomeMetrics({
    required this.isNewUser,
    required this.daily,
    required this.streak,
    required this.week,
    required this.level,
    required this.memorization,
    this.lastSession,
  });

  factory HomeMetrics.fromJson(Map<String, dynamic> json) =>
      _$HomeMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$HomeMetricsToJson(this);

  // Convenience getters
  int get dailyMinutes => (daily['minutes'] as num?)?.toInt() ?? 0;
  int get dailyGoal => (daily['goalMinutes'] as num?)?.toInt() ?? 10;
  double get dailyCompletion =>
      (daily['completionRatio'] as num?)?.toDouble() ?? 0.0;
  String get dailyStatus => (daily['status'] as String?) ?? "not_started";

  int get currentStreak => (streak['current'] as num?)?.toInt() ?? 0;
  int get longestStreak => (streak['longest'] as num?)?.toInt() ?? 0;

  int get weekMinutes => (week['totalMinutes'] as num?)?.toInt() ?? 0;
  int get weekDaysActive => (week['daysActive'] as num?)?.toInt() ?? 0;

  int get userLevel => (level['level'] as num?)?.toInt() ?? 1;
  int get totalXp => (level['xp'] as num?)?.toInt() ?? 0;
  double get percentToNextLevel =>
      (level['percentToNext'] as num?)?.toDouble() ?? 0.0;

  double get overallMemorization =>
      (memorization['overallPercent'] as num?)?.toDouble() ?? 0.0;

  List<Map<String, dynamic>> get topSurahs =>
      (memorization['topSurahs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
}

