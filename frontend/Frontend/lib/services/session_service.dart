import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tajweed_corrector/models/memorization_item.dart';
import 'package:tajweed_corrector/models/memorization_summary.dart';
import 'package:tajweed_corrector/models/session_models.dart';

/// Service for session and progress data
class SessionService {
  final Dio _dio;
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://192.168.100.11:8000',
  );

  SessionService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// Save a recitation session with mistakes
  Future<Map<String, dynamic>> saveSession({
    required String userId,
    required int surah,
    required int ayah,
    required String mode,
    required double accuracyScore,
    required double whisperScore,
    required double mfccScore,
    required int durationSeconds,
    required List<Map<String, dynamic>> mistakes,
    required int totalWords,
    required int correctWords,
    required int closeWords,
    required int missingWords,
    required int extraWords,
    String? referenceAudioUrl,
    String? transcribedText,
    String? correctText,
  }) async {
    try {
      final response = await _dio.post(
        '/api/sessions',
        data: {
          'userId': userId,
          'surah': surah,
          'ayah': ayah,
          'mode': mode,
          'accuracyScore': accuracyScore,
          'whisperScore': whisperScore,
          'mfccScore': mfccScore,
          'durationSeconds': durationSeconds,
          'mistakes': mistakes,
          'totalWords': totalWords,
          'correctWords': correctWords,
          'closeWords': closeWords,
          'missingWords': missingWords,
          'extraWords': extraWords,
          'referenceAudioUrl': referenceAudioUrl,
          'transcribedText': transcribedText ?? '',
          'correctText': correctText ?? '',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Failed to save session: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving session: $e');
      }
      rethrow;
    }
  }

  /// Get user's progress (weekly summary with recent recitations)
  Future<WeeklyProgressSummary> getUserProgress({
    required String userId,
    String? weekStart,
  }) async {
    try {
      final params = {'userId': userId};
      if (weekStart != null) {
        params['weekStart'] = weekStart;
      }

      final response = await _dio.get(
        '/api/user/progress',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        return WeeklyProgressSummary.fromJson(response.data as Map<String, dynamic>);
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

  /// Get home screen metrics (streak, minutes)
  Future<HomeMetricsWithStreak> getHomeMetrics({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/user/home-metrics',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return HomeMetricsWithStreak.fromJson(response.data as Map<String, dynamic>);
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

  /// Get mistakes summary
  Future<MistakesSummary> getMistakes({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/user/mistakes',
        queryParameters: {
          'userId': userId,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        return MistakesSummary.fromJson(response.data as Map<String, dynamic>);
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

  /// Get recent recitations
  Future<List<RecentRecitation>> getRecentRecitations({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/user/recitations',
        queryParameters: {
          'userId': userId,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final list = response.data as List;
        return list
            .map((item) => RecentRecitation.fromJson(item as Map<String, dynamic>))
            .toList();
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

  /// Get single session details
  Future<RecitationSession> getSessionDetail({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/sessions/$sessionId',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return RecitationSession.fromJson(response.data as Map<String, dynamic>);
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

  /// Get memorization summary (overall percent + surah summaries)
  Future<MemorizationSummary> getMemorizationSummary({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/memorization/summary',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        return MemorizationSummary.fromJson(response.data as Map<String, dynamic>);
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

  /// Update ayah memorization status after a memorization attempt.
  Future<MemorizationItem> updateMemorization({
    required String userId,
    required int surah,
    required int ayah,
    required double overallScore,
    required String sessionId,
    required List<Map<String, dynamic>> wordResults,
    String? recordedAt,
    double? whisperScore,
    double? mfccScore,
  }) async {
    final response = await _dio.post(
      '/api/memorization/update',
      data: {
        'userId': userId,
        'surah': surah,
        'ayah': ayah,
        'overallScore': overallScore,
        'whisperScore': whisperScore,
        'mfccScore': mfccScore,
        'wordResults': wordResults,
        'sessionId': sessionId,
        'recordedAt': recordedAt,
      },
    );

    if (response.statusCode == 200) {
      final payload = response.data as Map<String, dynamic>;
      return MemorizationItem.fromJson(payload['item'] as Map<String, dynamic>);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  /// Get recommended ayahs for today's memorization.
  Future<List<MemorizationTodayItem>> getMemorizationToday({
    required String userId,
    int limit = 5,
  }) async {
    final response = await _dio.get(
      '/api/memorization/today',
      queryParameters: {
        'userId': userId,
        'limit': limit,
      },
    );

    if (response.statusCode == 200) {
      final payload = response.data as Map<String, dynamic>;
      final list = (payload['items'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => MemorizationTodayItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  /// Get per-ayah memorization items (optional by surah).
  Future<List<MemorizationItem>> getMemorizationItems({
    required String userId,
    int? surahNumber,
  }) async {
    final params = <String, dynamic>{'userId': userId};
    if (surahNumber != null) {
      params['surah'] = surahNumber;
    }

    final response = await _dio.get(
      '/api/memorization/items',
      queryParameters: params,
    );

    if (response.statusCode == 200) {
      final payload = response.data as Map<String, dynamic>;
      final list = (payload['items'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => MemorizationItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}

