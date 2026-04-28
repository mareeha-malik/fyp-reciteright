import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tajweed_corrector/widgets/tajweed_colored_text.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tajweed_corrector/data/quran_data.dart';
import 'package:tajweed_corrector/services/session_service.dart';

/// Displays real DTW comparison results between user and Qari recitation
/// Shows: overall score, grade, waveforms, and detailed metrics breakdown
class ComparisonResultsScreen extends StatefulWidget {
  final int surah;
  final int verse;
  final Map<String, dynamic> comparisonResult;
  final String? referenceAudioUrl;
  final String? userAudioPath;
  final String recitationMode;

  const ComparisonResultsScreen({
    super.key,
    required this.surah,
    required this.verse,
    required this.comparisonResult,
    this.referenceAudioUrl,
    this.userAudioPath,
    this.recitationMode = 'practice',
  });

  @override
  State<ComparisonResultsScreen> createState() =>
      _ComparisonResultsScreenState();
}

class _ComparisonResultsScreenState extends State<ComparisonResultsScreen> {
  late AudioPlayer _userPlayer;
  late AudioPlayer _qariPlayer;
  final SessionService _sessionService = SessionService();
  bool _sessionSaved = false;
  String? _memorizationStatus;
  bool isPlayingUser = false;
  bool isPlayingQari = false;

  @override
  void initState() {
    super.initState();
    _userPlayer = AudioPlayer();
    _qariPlayer = AudioPlayer();

    _persistSessionFromResult();

    // Listen to player state changes
    _userPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() => isPlayingUser = playerState.playing);
      }
    });

    _qariPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() => isPlayingQari = playerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _userPlayer.dispose();
    _qariPlayer.dispose();
    super.dispose();
  }

  Future<void> _persistSessionFromResult() async {
    if (_sessionSaved) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final metrics = Map<String, dynamic>.from(
        widget.comparisonResult['metrics'] as Map? ?? const {},
      );
      final List<Map<String, dynamic>> words =
          (widget.comparisonResult['word_results'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      final mistakes = words
          .where((w) => w['status'] != 'correct')
          .map((w) {
            final tajweedRules = (w['tajweed_rules'] as List?)
                    ?.map((r) => (r is Map<String, dynamic>) ? (r['rule'] ?? '').toString() : r.toString())
                    .where((r) => r.isNotEmpty)
                    .toList() ??
                const <String>[];

            return {
              'word': (w['word'] ?? w['correct_word'] ?? '').toString(),
              'ayah': widget.verse,
              'surah': widget.surah,
              'tajweedRules': tajweedRules,
              'errorType': (w['status'] ?? 'mispronunciation').toString(),
              'similarity': ((w['similarity'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
              'occurredAt': DateTime.now().toUtc().toIso8601String(),
            };
          })
          .where((m) => (m['word'] as String).trim().isNotEmpty)
          .toList();

      final totalWords = words.length;
      final correctWords = words.where((w) => w['status'] == 'correct').length;
      final closeWords = words.where((w) => w['status'] == 'close').length;
      final missingWords = words.where((w) => w['status'] == 'missing').length;
      final extraWords = words.where((w) => w['status'] == 'extra').length;

      final durationSeconds =
          ((widget.comparisonResult['duration_seconds'] as num?)?.toInt() ??
                  ((widget.comparisonResult['inference_time_ms'] as num?)?.toInt() ?? 0) ~/ 1000)
              .clamp(1, 60 * 60);

      final saved = await _sessionService.saveSession(
        userId: user.uid,
        surah: widget.surah,
        ayah: widget.verse,
        mode: widget.recitationMode == 'memorization' ? 'memorization' : 'practice',
        accuracyScore: (widget.comparisonResult['overall_score'] as num?)?.toDouble() ?? 0.0,
        whisperScore: (metrics['whisper_score'] as num?)?.toDouble() ?? 0.0,
        mfccScore: (metrics['mfcc_score'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: durationSeconds,
        mistakes: mistakes,
        totalWords: totalWords,
        correctWords: correctWords,
        closeWords: closeWords,
        missingWords: missingWords,
        extraWords: extraWords,
        referenceAudioUrl: widget.referenceAudioUrl,
        transcribedText: (widget.comparisonResult['transcribed_text'] ?? '').toString(),
        correctText: (widget.comparisonResult['correct_text'] ?? '').toString(),
      );

      if (widget.recitationMode == 'memorization') {
        final updatedItem = await _sessionService.updateMemorization(
          userId: user.uid,
          surah: widget.surah,
          ayah: widget.verse,
          overallScore: (widget.comparisonResult['overall_score'] as num?)?.toDouble() ?? 0.0,
          sessionId: (saved['sessionId'] ?? '').toString(),
          wordResults: words,
          recordedAt: DateTime.now().toUtc().toIso8601String(),
          whisperScore: (metrics['whisper_score'] as num?)?.toDouble(),
          mfccScore: (metrics['mfcc_score'] as num?)?.toDouble(),
        );
        if (mounted) {
          setState(() {
            _memorizationStatus = updatedItem.status;
          });
        }
      }

      _sessionSaved = true;
    } catch (_) {
      // Non-blocking: UI should still display compare result even if metrics save fails.
    }
  }

  String _memorizationStatusLabel(String status) {
    switch (status) {
      case 'memorized':
        return 'Memorized';
      case 'learning':
        return 'Learning';
      case 'needs_review':
        return 'Needs review';
      default:
        return 'Not started';
    }
  }

  Color _memorizationStatusColor(String status) {
    switch (status) {
      case 'memorized':
        return const Color(0xFF2E7D32);
      case 'learning':
        return const Color(0xFF1565C0);
      case 'needs_review':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF757575);
    }
  }

  /// Get color based on accuracy score
  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50); // Green
    if (score >= 75) return const Color(0xFF2196F3); // Blue
    if (score >= 60) return const Color(0xFFFFC107); // Amber
    return const Color(0xFFF44336); // Red
  }

  /// Get grade based on score
  String _getGrade(double score) {
    if (score >= 95) return "Perfect 🌟";
    if (score >= 90) return "Excellent ✨";
    if (score >= 80) return "Very Good ✓";
    if (score >= 70) return "Good 👍";
    if (score >= 60) return "Satisfactory 📚";
    return "Needs Work 📚";
  }

  /// Play user's recording
  Future<void> _playUserRecording() async {
    try {
      if (_userPlayer.playing) {
        await _userPlayer.stop();
      } else if (widget.userAudioPath != null) {
        await _userPlayer.setFilePath(widget.userAudioPath!);
        await _userPlayer.play();
      }
    } catch (e) {
      _showSnackBar('❌ Could not play recording: $e', Colors.red);
    }
  }

  /// Play Qari's reference recording
  Future<void> _playQariRecording() async {
    try {
      if (_qariPlayer.playing) {
        await _qariPlayer.stop();
      } else if (widget.referenceAudioUrl != null) {
        await _qariPlayer.setUrl(widget.referenceAudioUrl!);
        await _qariPlayer.play();
      }
    } catch (e) {
      _showSnackBar('❌ Could not play Qari audio: $e', Colors.red);
    }
  }

   void _showSnackBar(String message, Color color) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: color,
         duration: const Duration(seconds: 2),
       ),
     );
   }

      /// Get Tajweed rule color by name
      Color _getTajweedColor(String ruleName) {
     ruleName = ruleName.toLowerCase();
     if (ruleName.contains('madd')) return const Color(0xFF1565C0);
     if (ruleName.contains('ghunnah')) return const Color(0xFF2E7D32);
     if (ruleName.contains('qalqalah')) return const Color(0xFFE65100);
     if (ruleName.contains('ikhfa')) return const Color(0xFF6A1B9A);
     if (ruleName.contains('idgham')) return const Color(0xFFB71C1C);
     if (ruleName.contains('izhar')) return const Color(0xFF00695C);
     if (ruleName.contains('shadda')) return const Color(0xFFF57F17);
     return Colors.grey;
      }

      String _getFixSuggestion(String status, String correctWord, String userWord, List<Map<String, dynamic>> tajweedRules) {
     if (status == 'missing') {
       return "This word was missing or skipped. Listen to the Qari and make sure to pronounce '$correctWord' clearly.";
     } else if (status == 'extra') {
       return "You added an extra word ('$userWord') that isn't in the Ayah. Keep pace with the text and avoid adding syllables.";
     }

     String suggestion = "Your pronunciation was unclear or incorrect. Try to articulate '$correctWord' more precisely.";
     
     if (userWord.isNotEmpty) {
       suggestion += " (You sounded like you said '$userWord').";
     }

     if (tajweedRules.isNotEmpty) {
       final ruleNames = tajweedRules.map((r) => r['rule'] ?? '').where((r) => r.toString().isNotEmpty).toList();
       if (ruleNames.isNotEmpty) {
         suggestion += "\n\nTip: Note these Tajweed rules for this word: ${ruleNames.join(', ')}.";
         if (ruleNames.any((r) => r.toString().toLowerCase().contains('qalqalah'))) {
           suggestion += " Don't forget to add a slight bounce or echo (Qalqalah).";
         }
         if (ruleNames.any((r) => r.toString().toLowerCase().contains('ghunnah'))) {
           suggestion += " Make sure to nasalize the sound (Ghunnah) for 2 counts.";
         }
         if (ruleNames.any((r) => r.toString().toLowerCase().contains('madd'))) {
           suggestion += " Ensure you elongate the vowel properly.";
         }
       }
     }
     return suggestion;
      }

      /// Show dialog with Tajweed rule explanation
      void _showTajweedDialog(String ruleName, String ruleArabic, String description) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisSize: MainAxisSize.min,
           children: [
             Text(
               ruleName,
               style: TextStyle(
                 color: _getTajweedColor(ruleName),
                 fontWeight: FontWeight.bold,
                 fontSize: 18,
               ),
             ),
             if (ruleArabic.isNotEmpty)
               Text(
                 ruleArabic,
                 style: GoogleFonts.scheherazadeNew(
                   color: _getTajweedColor(ruleName),
                   fontSize: 16,
                 ),
               ),
           ],
         ),
         content: Text(description),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('OK'),
           ),
         ],
       ),
     );
      }

  @override
  Widget build(BuildContext context) {
    final score = (widget.comparisonResult['overall_score'] as num?)?.toDouble() ?? 0.0;
    final grade = _getGrade(score);
    final feedback = widget.comparisonResult['feedback'] as String? ?? 'Good effort!';
    final inferenceTime = (widget.comparisonResult['inference_time_ms'] as num?)?.toDouble() ?? 0.0;

    // Extract metrics breakdown
    final metrics = Map<String, dynamic>.from(
      widget.comparisonResult['metrics'] as Map? ?? const {},
    );
    final hybrid = Map<String, dynamic>.from(
      widget.comparisonResult['hybrid_scoring'] as Map? ?? const {},
    );
    final whisperScore = (metrics['whisper_score'] as num?)?.toDouble() ?? 0.0;
    final dtwScore =
        (metrics['dtw_score'] as num?)?.toDouble() ??
        (hybrid['dtw_score'] as num?)?.toDouble() ??
        0.0;
    final directPhonemeScore =
        (metrics['direct_phoneme_score'] as num?)?.toDouble() ??
        (hybrid['direct_phoneme_score'] as num?)?.toDouble() ??
        0.0;
    final phonemeAccuracyScore =
        (metrics['phoneme_accuracy_score'] as num?)?.toDouble() ??
        (hybrid['phoneme_accuracy_score'] as num?)?.toDouble() ??
        0.0;
    final tajweedTimingScore =
        (metrics['tajweed_timing_score'] as num?)?.toDouble() ??
        (hybrid['tajweed_timing_score'] as num?)?.toDouble() ??
        0.0;
    final mfccScore = (metrics['mfcc_score'] as num?)?.toDouble() ?? 0.0;

    // Extract word results and tajweed summary if available
    final List<Map<String, dynamic>> wordResults =
        (widget.comparisonResult['word_results'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final tajweedSummary = Map<String, dynamic>.from(
      widget.comparisonResult['tajweed_summary'] as Map? ?? const {},
    );
    
      final teacherFeedback = Map<String, dynamic>.from(
        widget.comparisonResult['teacher_feedback'] as Map? ?? const {},
      );
      final correctTextText = widget.comparisonResult['correct_text'] as String? ?? '';
      final rulesBreakdown = Map<String, dynamic>.from(
      tajweedSummary['rules_breakdown'] as Map? ?? const {},
    );

    final surahName = getSurahName(widget.surah);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Comparison Results'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF1E4976).withValues(alpha: 0.3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────
            
              // ----------------------------------------------------------------
              // NEW SECTION: Tajweed Colored Text
              // ----------------------------------------------------------------
              if (correctTextText.isNotEmpty && wordResults.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Tajweed Preview",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E4976),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TajweedColoredText(
                        arabicText: correctTextText,
                        wordResults: wordResults,
                        showLabels: true,
                        interactive: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ----------------------------------------------------------------
              // NEW SECTION: Teacher Feedback
              // ----------------------------------------------------------------
              if (teacherFeedback.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    teacherFeedback['summary']?.toString() ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (teacherFeedback['priority_fix'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🔴 Most Important Fix:",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (teacherFeedback['priority_fix'] as Map)['how_to_fix']?.toString() ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  "📚 Tajweed Corrections",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E4976),
                  ),
                ),
                const SizedBox(height: 12),

                ...(teacherFeedback['feedback_items'] as List? ?? []).where((item) {
                  final i = item as Map;
                  return i['type'] == 'error' || i['type'] == 'missing';
                }).map((item) {
                  final i = item as Map;
                  final String hexColorStr = (i['color'] as String?)?.replaceAll('#', '') ?? '1E4976';
                  final Color ruleColor = Color(int.parse(hexColorStr.padLeft(8, 'ff'), radix: 16));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(left: BorderSide(color: ruleColor, width: 4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                i['word']?.toString() ?? '',
                                style: GoogleFonts.scheherazadeNew(fontSize: 22),
                                textDirection: TextDirection.rtl,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ruleColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: ruleColor),
                                ),
                                child: Text(
                                  i['rule']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ruleColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              i['message']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (i['duration'] != null && i['duration'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  "Duration: ${i['duration']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  i['how_to_fix']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 32),
              ],

              // SECTION 1: Overall Score Card
            // ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getScoreColor(score),
                    _getScoreColor(score).withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getScoreColor(score).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your Score',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${score.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    grade,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Surah ${widget.surah} - $surahName, Verse ${widget.verse}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (widget.recitationMode == 'memorization' && _memorizationStatus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _memorizationStatusColor(_memorizationStatus!).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _memorizationStatusColor(_memorizationStatus!)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_stories, color: _memorizationStatusColor(_memorizationStatus!)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Memorization status for this ayah: ${_memorizationStatusLabel(_memorizationStatus!)}',
                        style: TextStyle(
                          color: _memorizationStatusColor(_memorizationStatus!),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.recitationMode == 'memorization' && _memorizationStatus != null)
              const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 2: Feedback
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📝 Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feedback,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 3: Metrics Breakdown
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Metrics Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Word accuracy from ASR alignment (diagnostic)
                  _buildMetricRow(
                    'Word Accuracy (Whisper)',
                    whisperScore,
                    'Diagnostic',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  // MFCC timbre/energy similarity (Hybrid audio component)
                  _buildMetricRow(
                    'Audio Features (MFCC)',
                    mfccScore,
                    '20%',
                    Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  // DTW timing and phonetic-shape similarity
                  _buildMetricRow(
                    'Dynamic Time Warping (DTW)',
                    dtwScore,
                    'Phoneme Subscore',
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    'Direct Phoneme Match',
                    directPhonemeScore,
                    'Phoneme Subscore',
                    const Color(0xFF00897B),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    'Hybrid Phoneme Accuracy',
                    phonemeAccuracyScore,
                    '60%',
                    const Color(0xFF3949AB),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    'Tajweed Timing',
                    tajweedTimingScore,
                    '20%',
                    const Color(0xFF6D4C41),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 4: Word Results & Tajweed Rules
            // ─────────────────────────────────────────
            if (wordResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Word-by-Word Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4976),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Display word results
                    ...wordResults.map((wr) {
                      final word = wr['word'] as String? ?? '';
                      final transcribed = wr['transcribed'] as String? ?? '';
                      final status = wr['status'] as String? ?? 'wrong';
                      final color = wr['color'] as String? ?? 'red';
                      final tajweedRules = (wr['tajweed_rules'] as List? ?? const [])
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                      final phonemes = wr['phonemes'] as List? ?? [];
                      
                      Color statusColor;
                      if (color == 'green') {
                        statusColor = const Color(0xFF4CAF50);
                      } else if (color == 'orange') {
                        statusColor = const Color(0xFFFFC107);
                      } else {
                        statusColor = const Color(0xFFF44336);
                      }
                      
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(8),
                              color: statusColor.withValues(alpha: 0.05),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Word with Arabic font
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        word,
                                        style: GoogleFonts.scheherazadeNew(
                                          fontSize: 24,
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (transcribed.isNotEmpty && transcribed != word) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'You said: $transcribed',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                // Phonemes
                                if (phonemes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Phonemes: ${phonemes.join(' ')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF666666),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                // Detailed Feedback for mistakes
                                if (status != 'correct' && status != 'close') ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.lightbulb_outline, size: 16, color: statusColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _getFixSuggestion(status, word, transcribed, tajweedRules),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: statusColor.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // Tajweed rules for this word
                                if (tajweedRules.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: tajweedRules.map((rule) {
                                      final ruleName = rule['rule'] as String? ?? '';
                                      final ruleArabic = rule['arabic'] as String? ?? '';
                                      final ruleColor = rule['color'] as String? ?? '#000000';
                                      final description = rule['description'] as String? ?? '';
                                      final counts = (rule['counts'] as num?)?.toInt() ?? 0;
                                      
                                      Color ruleColorVal;
                                      try {
                                        ruleColorVal = Color(
                                          int.parse('FF${ruleColor.replaceAll('#', '')}', radix: 16),
                                        );
                                      } catch (_) {
                                        ruleColorVal = _getTajweedColor(ruleName);
                                      }
                                      
                                      String fullDesc = description;
                                      if (counts > 0) {
                                        fullDesc += ' (Extend for $counts counts)';
                                      }
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          _showTajweedDialog(ruleName, ruleArabic, fullDesc);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ruleColorVal.withValues(alpha: 0.2),
                                            border: Border.all(
                                              color: ruleColorVal,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                ruleName,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: ruleColorVal,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (ruleArabic.isNotEmpty)
                                                Text(
                                                  ruleArabic,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: ruleColorVal,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),

            if (wordResults.isNotEmpty) const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 5: Tajweed Summary
            // ─────────────────────────────────────────
            if (rulesBreakdown.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Tajweed Rules Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4976),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: rulesBreakdown.entries.map((entry) {
                        final ruleName = entry.key;
                        final count = (entry.value as num?)?.toInt() ?? 0;
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getTajweedColor(ruleName),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$ruleName ($count)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            if (rulesBreakdown.isNotEmpty) const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 6: Audio Playback
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎧 Listen to Recordings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User Recording
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _playUserRecording,
                      icon: Icon(
                        isPlayingUser ? Icons.pause_circle : Icons.play_circle,
                      ),
                      label: Text(
                        isPlayingUser ? '⏸ Stop Your Recording' : '▶ Play Your Recording',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Qari Recording
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _playQariRecording,
                      icon: Icon(
                        isPlayingQari ? Icons.pause_circle : Icons.play_circle,
                      ),
                      label: Text(
                        isPlayingQari ? '⏸ Stop Qari Recording' : '▶ Play Qari Recording',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

             const SizedBox(height: 24),

             // ─────────────────────────────────────────
             // SECTION 7: Timing Info
             // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⏱ Inference Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${inferenceTime.toStringAsFixed(0)}ms',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Back Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E4976),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('← Back to Practice'),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build metric progress row
  Widget _buildMetricRow(
    String label,
    double score,
    String weight,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                '${score.toStringAsFixed(1)}% ($weight)',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
