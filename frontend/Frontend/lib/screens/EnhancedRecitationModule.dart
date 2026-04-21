import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:tajweed_corrector/services/tajweed_service.dart';
import 'package:tajweed_corrector/services/recitation_service.dart';

class EnhancedRecitationModule extends StatefulWidget {
  final TajweedLesson lesson;

  const EnhancedRecitationModule({super.key, required this.lesson});

  @override
  State<EnhancedRecitationModule> createState() =>
      _EnhancedRecitationModuleState();
}

class _EnhancedRecitationModuleState extends State<EnhancedRecitationModule> {
  final RecitationService _recitationService = RecitationService();
  final TextEditingController _notesController = TextEditingController();

  // Recitation state
  bool isRecording = false;
  int recordingDuration = 0;
  double accuracy = 0.0;
  bool isPaused = false;
  List<double> waveformData = [];

  // Surah/Ayah selection
  String? selectedSurah;
  String? selectedAyah;

  final List<String> surahs = [
    'Surah Al-Fatiha',
    'Surah Al-Baqarah',
    'Surah Ali Imran',
    'Surah An-Nisa',
    'Surah Al-Maidah',
  ];

  final Map<String, List<String>> ayahs = {
    'Surah Al-Fatiha': [
      'Ayah 1',
      'Ayah 2',
      'Ayah 3',
      'Ayah 4',
      'Ayah 5',
      'Ayah 6',
      'Ayah 7',
    ],
    'Surah Al-Baqarah': ['Ayah 1-5', 'Ayah 6-10', 'Ayah 11-20', 'Ayah 21-39'],
    'Surah Ali Imran': ['Ayah 1-9', 'Ayah 10-20', 'Ayah 21-30'],
    'Surah An-Nisa': ['Ayah 1-6', 'Ayah 7-14', 'Ayah 15-25'],
    'Surah Al-Maidah': ['Ayah 1-5', 'Ayah 6-12', 'Ayah 13-20'],
  };

  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _generateMockWaveform();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _generateMockWaveform() {
    // Generate realistic waveform data
    waveformData = List.generate(100, (i) {
      double base = 0.3 + (i % 20) / 50;
      final angle = i * math.pi / 180;
      double variation = (math.sin(angle) + math.cos(angle / 2)) / 3;
      return (base + variation).clamp(0.0, 1.0);
    });
  }

  Future<void> _startRecitation() async {
    if (selectedSurah == null || selectedAyah == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both Surah and Ayah'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isRecording = true);
    recordingDuration = 0;

    // Simulate recording
    for (int i = 0; i < 15; i++) {
      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        recordingDuration += 1;
        // Simulate waveform update
        _generateMockWaveform();
      });
    }

    if (mounted) {
      setState(() {
        isRecording = false;
        isPaused = false;
        accuracy = 75 + (DateTime.now().millisecond % 25).toDouble();
      });
    }
  }

  void _pauseResume() {
    setState(() => isPaused = !isPaused);
  }

  void _stopRecording() {
    setState(() {
      isRecording = false;
      isPaused = false;
      recordingDuration = 0;
      selectedSurah = null;
      selectedAyah = null;
    });
  }

  Future<void> _submitRecitation() async {
    final success = await _recitationService.saveRecitation(
      lessonId: widget.lesson.id,
      lessonTitle: widget.lesson.title,
      duration: recordingDuration,
      accuracy: accuracy,
      notes: _notesController.text,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recitation submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => isSaved = true);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit recitation'),
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
        title: const Text('Recitation Module'),
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
            // Surah & Ayah Selection
            _buildSelectionCard(),
            const SizedBox(height: 24),

            // Waveform & Recording Display
            if (recordingDuration > 0 || isRecording) _buildWaveformCard(),
            if (recordingDuration > 0 || isRecording)
              const SizedBox(height: 24),

            // Recording Controls
            _buildRecordingControls(),
            const SizedBox(height: 24),

            // Accuracy Display
            if (recordingDuration > 0) _buildAccuracyCard(),
            if (recordingDuration > 0) const SizedBox(height: 24),

            // Notes
            _buildNotesCard(),
            const SizedBox(height: 24),

            // Submit Button
            if (recordingDuration > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitRecitation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Submit Recitation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Surah and Ayah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSurah,
            hint: const Text('Select Surah'),
            items:
                surahs.map((surah) {
                  return DropdownMenuItem(value: surah, child: Text(surah));
                }).toList(),
            onChanged: (value) {
              setState(() {
                selectedSurah = value;
                selectedAyah = null;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (selectedSurah != null)
            DropdownButtonFormField<String>(
              value: selectedAyah,
              hint: const Text('Select Ayah'),
              items:
                  ayahs[selectedSurah]!.map((ayah) {
                    return DropdownMenuItem(value: ayah, child: Text(ayah));
                  }).toList(),
              onChanged: (value) {
                setState(() => selectedAyah = value);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveformCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Real-time Waveform',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${recordingDuration}s',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4976),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Waveform visualization
          CustomPaint(
            painter: WaveformPainter(waveformData),
            size: const Size(double.infinity, 80),
          ),
          const SizedBox(height: 12),
          // Recording indicator
          if (isRecording)
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recording in progress...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!isRecording && recordingDuration == 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startRecitation,
                icon: const Icon(Icons.mic),
                label: const Text('Start Recitation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E4976),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else if (isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pauseResume,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _startRecitation,
                  icon: const Icon(Icons.mic),
                  label: const Text('Re-record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4976),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recitation Quality',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAccuracyMetric(
                'Accuracy',
                '${accuracy.toStringAsFixed(1)}%',
                accuracy > 80 ? Colors.green : Colors.orange,
              ),
              _buildAccuracyMetric(
                'Duration',
                '${recordingDuration}s',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Notes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add any notes about your recitation...',
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF1E4976),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Waveform Painter
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;

  WaveformPainter(this.waveformData);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..color = const Color(0xFF1E4976)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = (i * barWidth) + (barWidth / 2);
      final height = waveformData[i] * (size.height / 2);

      // Draw waveform bars
      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData;
  }
}
