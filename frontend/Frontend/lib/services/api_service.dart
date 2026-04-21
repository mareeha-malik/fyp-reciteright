import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tajweed_corrector/services/backend_config.dart';

/// API service for communicating with Python FastAPI backend
/// Handles audio comparison using DTW algorithm
class ApiService {
  static const String _baseUrl = BackendConfig.baseUrl;
  
  late Dio _dio;

  ApiService() {
    BackendConfig.debugPrintConfig();
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );

    // Add logging interceptor for debugging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) {
          if (kDebugMode) print(obj);
        },
      ),
    );
  }

  /// Compare user's recitation against reference Qari audio using DTW
  /// 
  /// Parameters:
  /// - userAudioBytes: Raw audio bytes from user's recording
  /// - surahNumber: Surah number (1-114)
  /// - verseNumber: Verse number
  /// - referenceAudioUrl: URL to reference Qari audio (e.g., EveryAyah Mishary Rashid)
  /// 
  /// Returns: Comparison result with overall score, word-level feedback, etc.
  Future<Map<String, dynamic>> compareRecitation({
    required List<int> userAudioBytes,
    required int surahNumber,
    required int verseNumber,
    required String referenceAudioUrl,
  }) async {
    try {
      // Encode user audio to base64
      final audioBase64 = base64.encode(userAudioBytes);

      // Prepare request
      final requestData = {
        'audio_base64': audioBase64,
        'reference_audio_url': referenceAudioUrl,
        'surah': surahNumber,
        'verse': verseNumber,
        'filename': 'user_recording.wav',
      };

      print('📤 Sending comparison request to backend...');
      print('   Surah: $surahNumber, Verse: $verseNumber');
      print('   Reference URL: $referenceAudioUrl');
      print('   User audio size: ${userAudioBytes.length} bytes');

      // Primary path: multipart (matches backend /api/compare used in main app flow).
      Response<dynamic> response;
      try {
        final multipartData = FormData.fromMap({
          'surah': surahNumber.toString(),
          'ayah': verseNumber.toString(),
          'reference_audio_url': referenceAudioUrl,
          'filename': 'user_recording.wav',
          'audio': MultipartFile.fromBytes(
            userAudioBytes,
            filename: 'user_recording.wav',
          ),
        });

        response = await _dio.post(
          '/api/compare',
          data: multipartData,
          options: Options(contentType: 'multipart/form-data'),
        );
      } on DioException catch (e) {
        // Fallback path for deployments expecting JSON/base64 payload.
        final code = e.response?.statusCode ?? 0;
        if (code == 400 || code == 404 || code == 415 || code == 422) {
          response = await _dio.post('/api/compare', data: requestData);
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        print('✅ Comparison successful!');
        
        // Extract and validate response data
        final dynamic raw = response.data;
        final Map<String, dynamic> result =
            raw is Map<String, dynamic>
                ? raw
                : (raw is Map)
                ? raw.cast<String, dynamic>()
                : (raw is String)
                ? (jsonDecode(raw) as Map<String, dynamic>)
                : <String, dynamic>{};
        
        if (result['success'] != true) {
          throw Exception('Backend returned success: false');
        }

        // Log results
        final overallScore = (result['overall_score'] as num?)?.toDouble() ?? 0.0;
        final grade = result['grade']?.toString() ?? 'Unknown';
        print('   Overall Score: ${overallScore.toStringAsFixed(1)}%');
        print('   Grade: $grade');
        print('   DTW Distance: ${result['dtw_distance']}');
        print('   Inference Time: ${result['inference_time_ms']} ms');

        return result;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout - make sure backend server is running at $_baseUrl');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout - comparison took too long');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Cannot reach backend at $_baseUrl (No route to host). Check phone and backend are on same network, or run with --dart-define=BACKEND_BASE_URL=http://<your-ip>:8000',
        );
      } else if (e.response != null) {
        final errorMsg = e.response?.data ?? e.message;
        throw Exception('Backend error: $errorMsg');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Comparison failed: $e');
    }
  }

  /// Predict Tajweed errors in user's recitation using trained model
  /// 
  /// Parameters:
  /// - audioBytes: Raw audio bytes from user's recording (WAV format)
  /// - filename: Optional filename for reference
  /// - surah: Optional surah number
  /// - verse: Optional verse number
  /// 
  /// Returns: Prediction result with detected errors, confidence scores, etc.
  Future<Map<String, dynamic>> predictTajweed({
    required List<int> audioBytes,
    String? filename,
    int? surah,
    int? verse,
  }) async {
    try {
      // Encode audio to base64
      final audioBase64 = base64.encode(audioBytes);

      // Prepare request
      final requestData = {
        'audio_base64': audioBase64,
        'filename': filename ?? 'recording.wav',
        'surah': surah,
        'verse': verse,
      };

      print('📤 Sending Tajweed prediction request...');
      print('   Audio size: ${audioBytes.length} bytes');

      // Send POST request to /api/predict-base64
      final response = await _dio.post(
        '/api/predict-base64',
        data: requestData,
      );

      if (response.statusCode == 200) {
        print('✅ Tajweed prediction successful!');
        
        final result = response.data as Map<String, dynamic>;
        
        // Extract predicted errors
        final detectedRules = List<String>.from(
          result['detected_rules'] as List? ?? [],
        );
        
        print('   Detected rules: $detectedRules');
        print('   Inference time: ${result['inference_time_ms']} ms');

        return result;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout - make sure backend is running');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout - prediction took too long');
      } else if (e.response != null) {
        throw Exception('Backend error: ${e.response?.data}');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Tajweed prediction failed: $e');
    }
  }

  /// Compare user audio against reference using DTW and get voice similarity score
  /// 
  /// Parameters:
  /// - userAudioBytes: Raw audio bytes from user's recording
  /// - referenceAudioBytes: Raw audio bytes from reference Qari recording
  /// - surah: Surah number
  /// - verse: Verse number
  /// 
  /// Returns: Comparison result with DTW score, grade, waveforms, etc.
  Future<Map<String, dynamic>> compareVoice({
    required List<int> userAudioBytes,
    required List<int> referenceAudioBytes,
    int? surah,
    int? verse,
  }) async {
    try {
      final userBase64 = base64.encode(userAudioBytes);
      final refBase64 = base64.encode(referenceAudioBytes);

      final requestData = {
        'user_audio_base64': userBase64,
        'reference_audio_base64': refBase64,
        'surah': surah,
        'verse': verse,
      };

      print('📤 Sending voice comparison request (DTW)...');
      
      final response = await _dio.post(
        '/api/compare-voice',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final result = response.data as Map<String, dynamic>;
        print('✅ Voice comparison successful!');
        print('   Overall score: ${result['overall_score']}%');
        print('   Grade: ${result['grade']}');
        return result;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Voice comparison failed: ${e.message}');
    }
  }

  /// Check API health status
  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get('/api/health');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        print('✅ API healthy: ${data['status']}');
        print('   Model loaded: ${data['model_loaded']}');
        print('   API version: ${data['api_version']}');
        return data;
      }
      throw Exception('Health check failed');
    } on DioException catch (e) {
      print('❌ Health check failed: ${e.message}');
      rethrow;
    }
  }

  /// Check basic API connectivity
  Future<bool> isConnected() async {
    try {
      final response = await _dio.get('/api/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Response model for comparison results
class ComparisonResultData {
  final bool success;
  final double overallScore; // 0-100%
  final String grade; // "Excellent" / "Good" / "Needs Work" / "Poor"
  final double dtwDistance;
  final List<double> userWaveform; // 200-point downsampled
  final List<double> referenceWaveform; // 200-point downsampled
  final List<WordScore>? wordScores;
  final String? referenceAudioUrl;
  final List<String>? tajweedErrors;
  final double inferenceTimeMs;
  final String timestamp;

  ComparisonResultData({
    required this.success,
    required this.overallScore,
    required this.grade,
    required this.dtwDistance,
    required this.userWaveform,
    required this.referenceWaveform,
    this.wordScores,
    this.referenceAudioUrl,
    this.tajweedErrors,
    required this.inferenceTimeMs,
    required this.timestamp,
  });

  factory ComparisonResultData.fromJson(Map<String, dynamic> json) {
    final wordScoresData = json['word_scores'] as List?;
    final wordScores = wordScoresData
        ?.map((w) => WordScore.fromJson(w as Map<String, dynamic>))
        .toList();

    return ComparisonResultData(
      success: json['success'] as bool? ?? false,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] as String? ?? 'Unknown',
      dtwDistance: (json['dtw_distance'] as num?)?.toDouble() ?? 0.0,
      userWaveform: List<double>.from(
        (json['user_waveform'] as List?)?.map((x) => (x as num).toDouble()) ??
            [],
      ),
      referenceWaveform: List<double>.from(
        (json['reference_waveform'] as List?)
                ?.map((x) => (x as num).toDouble()) ??
            [],
      ),
      wordScores: wordScores,
      referenceAudioUrl: json['reference_audio_url'] as String?,
      tajweedErrors: List<String>.from(json['tajweed_errors'] as List? ?? []),
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'overall_score': overallScore,
        'grade': grade,
        'dtw_distance': dtwDistance,
        'user_waveform': userWaveform,
        'reference_waveform': referenceWaveform,
        'word_scores': wordScores?.map((w) => w.toJson()).toList(),
        'reference_audio_url': referenceAudioUrl,
        'tajweed_errors': tajweedErrors,
        'inference_time_ms': inferenceTimeMs,
        'timestamp': timestamp,
      };
}

/// Word-level score from comparison
class WordScore {
  final String word;
  final double score; // 0-100
  final String color; // 'green', 'yellow', 'red'
  final String? error; // Tajweed error if any

  WordScore({
    required this.word,
    required this.score,
    required this.color,
    this.error,
  });

  factory WordScore.fromJson(Map<String, dynamic> json) {
    return WordScore(
      word: json['word'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      color: json['color'] as String? ?? 'gray',
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'score': score,
        'color': color,
        'error': error,
      };
}
