import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tajweed_corrector/models/gamification_models.dart';
import 'package:tajweed_corrector/services/backend_config.dart';

/// Service for fetching and managing gamification metrics
class GamificationService {
  final Dio _dio;
  static const String _baseUrl = BackendConfig.baseUrl;

  GamificationService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 180),
              sendTimeout: const Duration(seconds: 60),
            ));

  /// Fetch aggregated home metrics for user
  ///
  /// Returns:
  /// - HomeMetrics containing daily, weekly, streak, level, memorization data
  ///
  /// Throws:
  /// - DioException on network errors
  Future<HomeMetrics> getHomeMetrics({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/home-metrics',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return HomeMetrics.fromJson(
            response.data as Map<String, dynamic>);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Failed to fetch home metrics: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching home metrics: $e');
      }
      rethrow;
    }
  }

  /// Record a new session after recitation
  ///
  /// Args:
  /// - userId: User ID
  /// - surah: Surah number
  /// - startAyah: Starting ayah
  /// - endAyah: Ending ayah
  /// - durationMinutes: Duration of session
  /// - accuracyScore: Accuracy score (0-100)
  /// - mode: Session mode ("recitation", "tajweed_lesson", or "review")
  ///
  /// Returns:
  /// - Session object with XP earned and updated profile
  Future<Map<String, dynamic>> recordSession({
    required String userId,
    required int surah,
    required int startAyah,
    required int endAyah,
    required double durationMinutes,
    required double accuracyScore,
    required String mode,
  }) async {
    try {
      final response = await _dio.post(
        '/api/gamification/session',
        data: {
          'userId': userId,
          'surah': surah,
          'startAyah': startAyah,
          'endAyah': endAyah,
          'durationMinutes': durationMinutes,
          'accuracyScore': accuracyScore,
          'mode': mode,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Failed to record session: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording session: $e');
      }
      rethrow;
    }
  }

  /// Get daily progress for specific date
  Future<Map<String, dynamic>> getDailyProgress({
    required String userId,
    required String date, // YYYY-MM-DD
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/daily-progress',
        queryParameters: {
          'userId': userId,
          'date': date,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    }
  }

  /// Get weekly summary
  Future<Map<String, dynamic>> getWeekSummary({
    required String userId,
    required String weekStartDate, // YYYY-MM-DD (Monday)
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/week-summary',
        queryParameters: {
          'userId': userId,
          'weekStart': weekStartDate,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    }
  }

  /// Get streak information
  Future<StreakInfo> getStreakInfo({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/streak',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return StreakInfo.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    }
  }

  /// Get current level info
  Future<LevelInfo> getLevelInfo({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/level',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return LevelInfo.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    }
  }

  /// Get memorization progress
  Future<Map<String, dynamic>> getMemorizationProgress({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/gamification/memorization',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    }
  }

  /// Update user's daily goal
  Future<void> updateDailyGoal({
    required String userId,
    required int dailyGoalMinutes,
  }) async {
    try {
      await _dio.put(
        '/api/gamification/daily-goal',
        data: {
          'userId': userId,
          'dailyGoalMinutes': dailyGoalMinutes,
        },
      );
    } on DioException {
      rethrow;
    }
  }
}

