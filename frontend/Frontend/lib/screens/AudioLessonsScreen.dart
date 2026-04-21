import 'package:flutter/material.dart';
import 'package:tajweed_corrector/services/quran_audio_service.dart';
import 'package:tajweed_corrector/services/tajweed_tts_service.dart';
import 'package:tajweed_corrector/services/lesson_recording_service.dart';
import 'dart:async';

class AudioLessonsScreen extends StatefulWidget {
  const AudioLessonsScreen({super.key});

  @override
  State<AudioLessonsScreen> createState() => _AudioLessonsScreenState();
}

class _AudioLessonsScreenState extends State<AudioLessonsScreen> {
  final List<String> _tajweedRules = [
    'Ghunna',
    'Ikhfa',
    'Idhar',
    'Madd',
    'Qalqalah',
    'Tafkheem',
    'Tarqeeq',
  ];

  String _selectedRule = 'Ghunna';
  bool _isLoadingAudio = false;
  bool _isRecording = false;
  List<Map<String, dynamic>> _audioExamples = [];
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  int? _recordingAccuracy;
  String? _recordingStatus;
  List<Map<String, dynamic>> _pastRecordings = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await TajweedTTSService.initialize();
    _loadAudioExamples();
    _loadPastRecordings();
  }

  Future<void> _loadAudioExamples() async {
    setState(() => _isLoadingAudio = true);
    try {
      final examples = await QuranAudioService.getTajweedExamples(
        ruleName: _selectedRule,
      );
      setState(() => _audioExamples = examples);
    } catch (e) {
      print('Error loading examples: $e');
    } finally {
      setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _loadPastRecordings() async {
    try {
      final recordings = await LessonRecordingService.getLessonRecordings(
        _selectedRule,
      );
      setState(() {
        _pastRecordings = recordings;
      });
    } catch (e) {
      print('Error loading past recordings: $e');
    }
  }

  Future<void> _playRuleExplanation() async {
    final explanation =
        TajweedTTSService.getRuleExplanations()[_selectedRule] ?? '';
    if (explanation.isNotEmpty) {
      await TajweedTTSService.speakRuleExplanation(_selectedRule, explanation);
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      // Start recording
      try {
        await LessonRecordingService.startRecording(
          _selectedRule,
          _selectedRule,
        );

        // Start timer
        _recordingSeconds = 0;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _recordingSeconds++;
            });
          }
        });

        setState(() => _isRecording = true);
        _recordingStatus = 'Recording...';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔴 Recording started... Speak now!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Stop recording
      try {
        _recordingTimer?.cancel();
        final result = await LessonRecordingService.stopRecording(_selectedRule);

        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordingStatus = result;
            _recordingAccuracy = null; // Will be loaded from Firestore
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $result'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload past recordings
          _loadPastRecordings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error stopping recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Tajweed Lessons'),
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
            // Rule Selector
            const Text(
              'Select Tajweed Rule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tajweedRules
                    .map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedRule == rule
                                ? const Color(0xFF1E4976)
                                : Colors.grey[300],
                          ),
                          onPressed: () {
                            setState(() => _selectedRule = rule);
                            _loadAudioExamples();
                          },
                          child: Text(
                            rule,
                            style: TextStyle(
                              color: _selectedRule == rule
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Rule Explanation with Audio
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1E4976),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedRule,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4976),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.volume_up, size: 18),
                          label: const Text('Hear Explanation', overflow: TextOverflow.ellipsis),
                          onPressed: _playRuleExplanation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Stop', overflow: TextOverflow.ellipsis),
                          onPressed: TajweedTTSService.stop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Audio Examples from Quran
            const Text(
              'Quran Audio Examples',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingAudio
                ? const Center(child: CircularProgressIndicator())
                : _audioExamples.isEmpty
                    ? const Center(
                        child: Text('No audio examples available'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _audioExamples.length,
                        itemBuilder: (context, index) {
                          final example = _audioExamples[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(example['description']),
                              subtitle: Text(
                                'Surah ${example['surah']}, Ayah ${example['ayah']}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle),
                                color: const Color(0xFF1E4976),
                                onPressed: () async {
                                  try {
                                    // Play Quran audio example
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('▶️ Playing Quran audio...'),
                                      ),
                                    );
                                  } catch (e) {
                                    print('Error playing audio: $e');
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 24),

            // User Recording Practice
            const Text(
              'Practice Your Recitation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.grey[300]!,
                  width: _isRecording ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: _isRecording ? Colors.red : const Color(0xFF1E4976),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? '🔴 Recording...' : '⏹️ Ready to Record',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isRecording)
                    Text(
                      _formatDuration(_recordingSeconds),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontFamily: 'monospace',
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isRecording ? Colors.red : const Color(0xFF1E4976),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _toggleRecording,
                  ),
                  if (_recordingStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        _recordingStatus!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Past Recordings
            if (_pastRecordings.isNotEmpty) ...[
              const Text(
                'Your Practice History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pastRecordings.length,
                itemBuilder: (context, index) {
                  final recording = _pastRecordings[index];
                  final accuracy = recording['accuracy'] as int? ?? 0;
                  final duration = recording['duration'] as int? ?? 0;
                  final accuracyColor = accuracy > 85
                      ? Colors.green
                      : accuracy > 70
                          ? Colors.orange
                          : Colors.red;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        decoration: BoxDecoration(
                          color: accuracyColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '$accuracy%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accuracyColor,
                          ),
                        ),
                      ),
                      title: Text(recording['lessonTitle']),
                      subtitle:
                          Text('${_formatDuration(duration)} - Accuracy: $accuracy%'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await LessonRecordingService.deleteRecording(
                            recording['id'],
                          );
                          _loadPastRecordings();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    TajweedTTSService.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }
}




