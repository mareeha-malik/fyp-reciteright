import 'package:flutter/material.dart';

class FeedbackData {
  final String userText;
  final String qariText;
  final List<FeedbackError> errors;
  final String suggestion;

  FeedbackData({
    required this.userText,
    required this.qariText,
    required this.errors,
    required this.suggestion,
  });

  /// ✨ NEW: Create FeedbackData from API voice comparison response
  factory FeedbackData.fromComparisonResponse(Map<String, dynamic> response) {
    final feedback = response['feedback'] as String? ?? 'Analysis complete.';

    // Parse feedback string for basic error extraction
    final errors = <FeedbackError>[];
    final suggestion = feedback;

    return FeedbackData(
      userText: 'Your Recitation',
      qariText: 'Qari\'s Recitation',
      errors: errors,
      suggestion: suggestion,
    );
  }

  /// ✨ NEW: Create FeedbackData from Tajweed prediction response
  factory FeedbackData.fromPredictionResponse(Map<String, dynamic> response) {
    final detectedRules = response['detected_rules'] as List? ?? [];

    final errors = <FeedbackError>[];
    int position = 0;

    // Create error entries for each detected Tajweed rule
    for (final rule in detectedRules) {
      errors.add(
        FeedbackError(
          position: position++,
          word: rule.toString(),
          errorType: 'major', // Tajweed rules are significant
          correction: 'Apply proper $rule pronunciation',
        ),
      );
    }

    final feedback =
        detectedRules.isEmpty
            ? 'Perfect recitation with correct Tajweed application!'
            : 'Detected ${detectedRules.length} Tajweed rule(s): ${detectedRules.join(", ")}';

    return FeedbackData(
      userText: 'Your Recitation',
      qariText: 'Perfect Tajweed',
      errors: errors,
      suggestion: feedback,
    );
  }
}

class FeedbackError {
  final int position;
  final String word;
  final String errorType; // 'major', 'minor', 'correct'
  final String? correction;

  FeedbackError({
    required this.position,
    required this.word,
    required this.errorType,
    this.correction,
  });
}

class FeedbackModule extends StatefulWidget {
  final FeedbackData feedbackData;
  final VoidCallback? onPlayUserRecitation;
  final VoidCallback? onPlayQariRecitation;

  const FeedbackModule({
    super.key,
    required this.feedbackData,
    this.onPlayUserRecitation,
    this.onPlayQariRecitation,
  });

  @override
  State<FeedbackModule> createState() => _FeedbackModuleState();
}

class _FeedbackModuleState extends State<FeedbackModule> {
  bool _showComparison = true;
  bool _isPlayingUser = false;
  bool _isPlayingQari = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Recitation Feedback'),
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
            // Color-Coded Text Display
            _buildColorCodedText(),
            const SizedBox(height: 24),

            // Error Details
            _buildErrorDetailsCard(),
            const SizedBox(height: 24),

            // Side-by-Side Comparison
            _buildComparisonToggle(),
            if (_showComparison) _buildComparisonView(),
            const SizedBox(height: 24),

            // Playback Controls
            _buildPlaybackControls(),
            const SizedBox(height: 24),

            // Suggestions & Tips
            _buildSuggestionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCodedText() {
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
            'Your Recitation (Color-Coded)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildColorCodedWords(),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Correct', Colors.green),
              _buildLegendItem('Minor Error', Colors.orange),
              _buildLegendItem('Major Error', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColorCodedWords() {
    final widgets = <Widget>[];
    final words = widget.feedbackData.userText.split(' ');

    for (int i = 0; i < words.length; i++) {
      final error = _findErrorAtPosition(i);

      final color =
          error == null
              ? Colors.green
              : error.errorType == 'major'
              ? Colors.red
              : Colors.orange;

      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            words[i],
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return widgets;
  }

  FeedbackError? _findErrorAtPosition(int position) {
    for (final error in widget.feedbackData.errors) {
      if (error.position == position) {
        return error;
      }
    }
    return null;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildErrorDetailsCard() {
    final errors =
        widget.feedbackData.errors
            .where((e) => e.errorType != 'correct')
            .toList();

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
                'Errors Found',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: errors.isEmpty ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${errors.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (errors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '✓ Perfect recitation! No errors found.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: errors.length,
              itemBuilder: (context, index) {
                final error = errors[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          error.errorType == 'major'
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                      border: Border(
                        left: BorderSide(
                          color:
                              error.errorType == 'major'
                                  ? Colors.red
                                  : Colors.orange,
                          width: 4,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${error.errorType.toUpperCase()} ERROR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    error.errorType == 'major'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '"${error.word}"',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (error.correction != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Correct: "${error.correction}"',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Side-by-Side Comparison',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Switch(
          value: _showComparison,
          onChanged: (value) => setState(() => _showComparison = value),
          activeColor: const Color(0xFF1E4976),
        ),
      ],
    );
  }

  Widget _buildComparisonView() {
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
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Your Recitation',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Qari's Recitation",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Text(
                    widget.feedbackData.userText,
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    widget.feedbackData.qariText,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
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
            'Playback',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isPlayingUser = !_isPlayingUser);
                    widget.onPlayUserRecitation?.call();
                  },
                  icon: Icon(_isPlayingUser ? Icons.pause : Icons.play_arrow),
                  label: const Text('Your Recitation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isPlayingQari = !_isPlayingQari);
                    widget.onPlayQariRecitation?.call();
                  },
                  icon: Icon(_isPlayingQari ? Icons.pause : Icons.play_arrow),
                  label: const Text('Qari Recitation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
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
            'Suggestions & Practice Tips',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Text(
              widget.feedbackData.suggestion,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 8),
                Text(
                  '• Listen to the Qari\'s recitation multiple times\n'
                  '• Practice the correct pronunciation slowly\n'
                  '• Focus on the areas marked as errors\n'
                  '• Record and compare with the Qari\'s version\n'
                  '• Practice daily for best results',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
