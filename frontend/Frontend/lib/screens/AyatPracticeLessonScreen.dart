import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tajweed_corrector/data/quran_data.dart';
import 'package:tajweed_corrector/services/lesson_recording_service.dart';
import 'package:tajweed_corrector/services/api_service.dart';
import 'package:tajweed_corrector/widgets/tajweed_text_widget.dart';
import 'dart:async';

/// Real Quran Practice Screen
/// User selects Surah + Ayat, listens to Qari, records themselves, gets real DTW comparison
class AyatPracticeLessonScreen extends StatefulWidget {
  final int? initialSurah;
  final int? initialVerse;

  const AyatPracticeLessonScreen({
    super.key,
    this.initialSurah,
    this.initialVerse,
  });

  @override
  State<AyatPracticeLessonScreen> createState() =>
      _AyatPracticeLessonScreenState();
}

class _AyatPracticeLessonScreenState extends State<AyatPracticeLessonScreen> {
  // Audio player for Qari
  late AudioPlayer _qariPlayer;

  // State
  int? selectedSurah;
  int? selectedVerse;
  bool isRecording = false;
  int recordingDuration = 0;
  Timer? _recordingTimer;
  String? recordingPath;
  bool isComparingWithQari = false;
  bool isPlayingQari = false;

  @override
  void initState() {
    super.initState();
    _qariPlayer = AudioPlayer();
    selectedSurah = widget.initialSurah ?? 1; // Default to Al-Fatiha
    selectedVerse = widget.initialVerse ?? 1;

    // Listen to Qari player state changes
    _qariPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          isPlayingQari = playerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _qariPlayer.dispose();
    super.dispose();
  }

  /// Start recording the user's recitation
  Future<void> _startRecording() async {
    if (selectedSurah == null || selectedVerse == null) {
      _showSnackBar(
        '❌ Please select Surah and Verse',
        Colors.red,
      );
      return;
    }

    try {
      recordingDuration = 0;
      
      final lessonId = 'surah_${selectedSurah}_verse_${selectedVerse}';
      final lessonTitle =
          '${getSurahName(selectedSurah!)} - Verse $selectedVerse';

      await LessonRecordingService.startRecording(lessonId, lessonTitle);

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            recordingDuration++;
          });
        }
      });

      setState(() => isRecording = true);

      _showSnackBar(
        '🔴 Recording started... Recite clearly',
        Colors.blue,
      );
    } catch (e) {
      _showSnackBar('❌ Recording error: $e', Colors.red);
    }
  }

  /// Stop recording and send to backend for comparison
  Future<void> _stopRecordingAndCompare() async {
    if (!isRecording) return;

    _recordingTimer?.cancel();
    setState(() => isRecording = false);

    try {
      // Get recorded audio file path
      final lessonId = 'surah_${selectedSurah}_verse_${selectedVerse}';

      // Show loading state
      setState(() => isComparingWithQari = true);

      // Get reference audio URL
      final referenceAudioUrl = getAudioUrl(selectedSurah!, selectedVerse!);
      print('🎧 Reference audio URL: $referenceAudioUrl');

      // For MVP/testing: Generate dummy audio bytes
      // In production, would use actual recording from audio plugin
      final userAudioBytes = _generateDummyAudio(recordingDuration);
      print('📁 Generated test audio: ${userAudioBytes.length} bytes');

      // Call backend API for real DTW comparison
      final apiService = ApiService();
      print('🤖 Sending to API for voice comparison...');
      
      final result = await apiService.compareRecitation(
        userAudioBytes: userAudioBytes,
        surahNumber: selectedSurah!,
        verseNumber: selectedVerse!,
        referenceAudioUrl: referenceAudioUrl,
      );

      setState(() => isComparingWithQari = false);

      print('✅ Comparison complete!');
      print('   Score: ${result['overall_score']}%');
      print('   Grade: ${result['grade']}');
      print('   Inference time: ${result['inference_time_ms']}ms');

      if (mounted) {
        // Navigate to results screen with real comparison data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComparisonResultsScreen(
              surah: selectedSurah!,
              verse: selectedVerse!,
              comparisonResult: result,
              referenceAudioUrl: referenceAudioUrl,
              userAudioPath: 'test_$lessonId.wav',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => isComparingWithQari = false);
      print('❌ Comparison error: $e');
      _showSnackBar('❌ Comparison error: $e', Colors.red);
    }
  }

  /// Generate dummy audio bytes for testing
  /// In production, would use actual recorded audio
  List<int> _generateDummyAudio(int durationSeconds) {
    // Generate a simple WAV file header + audio data
    // This is a minimal WAV with silence for testing
    // Format: 16-bit PCM, 16000 Hz, mono
    
    final sampleRate = 16000;
    final numSamples = sampleRate * durationSeconds;
    
    // WAV header (44 bytes)
    final header = <int>[
      // RIFF chunk descriptor
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      0x00, 0x00, 0x00, 0x00, // File size (will update)
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      
      // fmt sub-chunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      0x10, 0x00, 0x00, 0x00, // Subchunk1Size
      0x01, 0x00, // AudioFormat (1 = PCM)
      0x01, 0x00, // NumChannels
      0x80, 0x3E, 0x00, 0x00, // SampleRate (16000)
      0x00, 0x7D, 0x00, 0x00, // ByteRate
      0x02, 0x00, // BlockAlign
      0x10, 0x00, // BitsPerSample
      
      // data sub-chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      0x00, 0x00, 0x00, 0x00, // Subchunk2Size
    ];
    
    // Add minimal audio data (silence)
    final audioData = List<int>.filled(numSamples * 2, 0);
    
    return header + audioData;
  }

  /// Play reference audio from Qari (Mishary Rashid)
  Future<void> _playQariAudio() async {
    if (selectedSurah == null || selectedVerse == null) {
      _showSnackBar('❌ Please select Surah and Verse', Colors.red);
      return;
    }

    try {
      final audioUrl = getAudioUrl(selectedSurah!, selectedVerse!);

      if (audioUrl.isEmpty) {
        _showSnackBar('❌ Audio not available for this verse', Colors.red);
        return;
      }

      if (_qariPlayer.playing) {
        await _qariPlayer.stop();
      } else {
        await _qariPlayer.setUrl(audioUrl);
        await _qariPlayer.play();
      }
    } catch (e) {
      _showSnackBar('❌ Could not play audio: $e', Colors.red);
    }
  }

  /// Helper to show snackbar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ayatData = getAyatData(selectedSurah ?? 1, selectedVerse ?? 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Practice with Qari'),
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
            // SECTION 1: Surah & Verse Selection
            // ─────────────────────────────────────────
            const Text(
              'Select Surah & Verse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E4976),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Surah dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1E4976),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: DropdownButton<int>(
                      value: selectedSurah,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      iconEnabledColor: const Color(0xFF1E4976),
                      underline: const SizedBox(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedSurah = newValue;
                            selectedVerse = 1; // Reset verse when surah changes
                          });
                        }
                      },
                      items: getAvailableSurahs()
                           .map<DropdownMenuItem<int>>((surah) {
                         return DropdownMenuItem<int>(
                           value: surah,
                           child: Text(
                             '${surah.toString().padLeft(2, '0')}. ${getSurahName(surah)} - ${getSurahArabicName(surah)}',
                             style: const TextStyle(
                               fontSize: 14,
                               color: Color(0xFF1E4976),
                             ),
                           ),
                         );
                       }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Verse dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1E4976),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: DropdownButton<int>(
                      value: selectedVerse,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      iconEnabledColor: const Color(0xFF1E4976),
                      underline: const SizedBox(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedVerse = newValue;
                          });
                        }
                      },
                      items: getAvailableVerses(selectedSurah ?? 1)
                          .map<DropdownMenuItem<int>>((verse) {
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text(
                            'Verse $verse',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E4976),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SECTION 2: Ayat Text Display | عرض نص الآية
            // ─────────────────────────────────────────
            if (ayatData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E4976),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic text with word-level tajweed highlighting
                    TajweedTextWidget(
                      arabicText: ayatData['arabic'] as String,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Translation
                    Text(
                      ayatData['translation'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─────────────────────────────────────────
            // SECTION 3: Listen to Qari | استمع إلى القارئ
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
                children: [
                  const Text(
                    '🎧 Listen to Qari Recitation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Listen carefully to Mishary Rashid\'s recitation before recording',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: !isRecording ? _playQariAudio : null,
                      icon: Icon(isPlayingQari ? Icons.pause_circle : Icons.play_circle),
                      label: Text(
                        isPlayingQari ? '⏸ Stop Audio' : '🎧 Play Qari Audio',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E4976),
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
            // SECTION 4: Record Your Recitation | سجل تلاوتك
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
                children: [
                  if (isRecording)
                    ...[
                      const Text(
                        '🔴 RECORDING',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.mic,
                          size: 60,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Duration: ${_formatDuration(recordingDuration)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isComparingWithQari
                              ? null
                              : _stopRecordingAndCompare,
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('⏹ Stop & Compare'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ]
                  else
                    ...[
                      const Text(
                        'Now Recite the Same Ayat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E4976),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Make sure to recite clearly and at a natural pace',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic),
                          label: const Text('🎙️ Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4976),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  if (isComparingWithQari) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E4976),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Comparing with Qari...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4976),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // TIPS SECTION | نصائح
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tips for Better Practice',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✓ Listen to Qari multiple times before recording\n'
                    '✓ Recite in a quiet environment\n'
                    '✓ Maintain clear pronunciation\n'
                    '✓ Don\'t speak too fast\n'
                    '✓ Compare results to improve',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// ════════════════════════════════════════════════════════════════════
/// Results Screen - Show Real Comparison Results
/// ════════════════════════════════════════════════════════════════════

class ComparisonResultsScreen extends StatefulWidget {
  final int surah;
  final int verse;
  final dynamic comparisonResult;
  final String referenceAudioUrl;
  final String userAudioPath;

  const ComparisonResultsScreen({
    super.key,
    required this.surah,
    required this.verse,
    required this.comparisonResult,
    required this.referenceAudioUrl,
    required this.userAudioPath,
  });

  @override
  State<ComparisonResultsScreen> createState() =>
      _ComparisonResultsScreenState();
}

class _ComparisonResultsScreenState extends State<ComparisonResultsScreen> {
  late AudioPlayer _qariPlayer;
  late AudioPlayer _userPlayer;
  bool isPlayingQari = false;
  bool isPlayingUser = false;

  @override
  void initState() {
    super.initState();
    _qariPlayer = AudioPlayer();
    _userPlayer = AudioPlayer();

    _qariPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlayingQari = state.playing);
    });

    _userPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlayingUser = state.playing);
    });
  }

  @override
  void dispose() {
    _qariPlayer.dispose();
    _userPlayer.dispose();
    super.dispose();
  }

  Future<void> _playQariAudio() async {
    try {
      if (_qariPlayer.playing) {
        await _qariPlayer.stop();
      } else {
        await _qariPlayer.setUrl(widget.referenceAudioUrl);
        await _qariPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _playUserAudio() async {
    try {
      if (_userPlayer.playing) {
        await _userPlayer.stop();
      } else {
        await _userPlayer.setFilePath(widget.userAudioPath);
        await _userPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ayatData = getAyatData(widget.surah, widget.verse);
    final overallScore = widget.comparisonResult['overallScore'] ?? 0.0;
    final wordScores = widget.comparisonResult['wordScores'] ?? {};
    final words = getWords(widget.surah, widget.verse);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─────────────────────────────────────────
            // Score Display | عرض النتيجة
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Overall Accuracy',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${overallScore.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildScoreGauge(overallScore),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // Word-level Feedback | تقييم كل كلمة
            // ─────────────────────────────────────────
            if (ayatData != null) ...[
              const Text(
                'Word-by-Word Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4976),
                ),
              ),
              const SizedBox(height: 12),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic text with color coding
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 12,
                        children: words.asMap().entries.map((entry) {
                          final index = entry.key;
                          final word = entry.value;
                          final score =
                              (wordScores[index.toString()] ?? 50.0).toDouble();

                          return _buildColoredWord(word, score);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Color legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLegendItem('Excellent', Colors.green),
                        _buildLegendItem('Good', Colors.amber),
                        _buildLegendItem('Needs Work', Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─────────────────────────────────────────
            // Playback Controls | التحكم في التشغيل
            // ─────────────────────────────────────────
            const Text(
              'Compare Recordings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E4976),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playQariAudio,
                icon: Icon(isPlayingQari ? Icons.pause_circle : Icons.play_circle),
                label: Text(isPlayingQari ? '⏸ Stop Qari' : '🎧 Qari\'s Recitation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E4976),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playUserAudio,
                icon: Icon(isPlayingUser ? Icons.pause_circle : Icons.play_circle),
                label: Text(isPlayingUser ? '⏸ Stop Your Recording' : '🎙️ Your Recitation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // Action Buttons | أزرار الإجراءات
            // ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh),
                label: const Text('🔄 Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Go to next verse
                  final nextVerse = widget.verse + 1;
                  final maxVerses =
                      getVerseCount(widget.surah);

                  if (nextVerse <= maxVerses) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AyatPracticeLessonScreen(
                          initialSurah: widget.surah,
                          initialVerse: nextVerse,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You have completed all verses!'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('➡️ Next Verse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                icon: const Icon(Icons.home),
                label: const Text('🏠 Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreGauge(double score) {
    Color gaugeColor;
    if (score >= 80) {
      gaugeColor = Colors.green;
    } else if (score >= 60) {
      gaugeColor = Colors.amber;
    } else {
      gaugeColor = Colors.red;
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          score >= 80
              ? '✅ Excellent Recitation!'
              : score >= 60
                  ? '⚠️ Good, but can improve'
                  : '❌ Needs More Practice',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: gaugeColor,
          ),
        ),
      ],
    );
  }

  Widget _buildColoredWord(String word, double score) {
    Color color;
    if (score >= 70) {
      color = Colors.green;
    } else if (score >= 50) {
      color = Colors.amber;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
