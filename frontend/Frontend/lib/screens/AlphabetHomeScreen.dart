import 'package:flutter/material.dart';
import 'package:tajweed_corrector/models/arabic_letter.dart';
import 'package:tajweed_corrector/services/alphabet_service.dart';
import 'package:tajweed_corrector/screens/LetterDetailScreen.dart';

class AlphabetHomeScreen extends StatefulWidget {
  const AlphabetHomeScreen({super.key});

  @override
  State<AlphabetHomeScreen> createState() => _AlphabetHomeScreenState();
}

class _AlphabetHomeScreenState extends State<AlphabetHomeScreen> {
  final AlphabetService _alphabetService = AlphabetService();
  List<ArabicLetter> _letters = [];
  Map<String, ArabicLetterProgress> _progress = {};
  AlphabetProgressSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final letters = await _alphabetService.getLetters();
    final progressMap = <String, ArabicLetterProgress>{};
    for (final letter in letters) {
      progressMap[letter.id] = await _alphabetService.getLetterProgress(letter.id);
    }
    final summary = await _alphabetService.getProgressSummary();

    if (!mounted) return;
    setState(() {
      _letters = letters;
      _progress = progressMap;
      _summary = summary;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Arabic Alphabet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E4976),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(theme),
                  const SizedBox(height: 16),
                  ..._buildLessonSections(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final summary = _summary;
    final learned = summary?.learnedLetters ?? 0;
    final total = summary?.totalLetters ?? _letters.length;
    final currentStreak = summary?.currentStreak ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E4976), Color(0xFF2E5F8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arabic Alphabet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$learned / $total letters learned',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : learned / total,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Streak: $currentStreak days',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          )
        ],
      ),
    );
  }

  List<Widget> _buildLessonSections() {
    final Map<int, List<ArabicLetter>> grouped = {};
    for (final letter in _letters) {
      grouped.putIfAbsent(letter.lessonIndex, () => []).add(letter);
    }

    final lessonIndexes = grouped.keys.toList()..sort();
    return lessonIndexes.map((lessonIndex) {
      final letters = grouped[lessonIndex] ?? [];
      final label = letters.isNotEmpty ? letters.first.lessonLabel : 'Lesson $lessonIndex';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E4976),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: letters.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final letter = letters[index];
              final progress = _progress[letter.id] ?? ArabicLetterProgress.empty();
              return _buildLetterTile(letter, progress);
            },
          ),
          const SizedBox(height: 20),
        ],
      );
    }).toList();
  }

  Widget _buildLetterTile(ArabicLetter letter, ArabicLetterProgress progress) {
    final isMastered = progress.isMastered;
    final tileColor = isMastered ? const Color(0xFFE8F5E9) : Colors.white;
    final borderColor = isMastered ? const Color(0xFF4CAF50) : Colors.grey[200]!;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LetterDetailScreen(letter: letter)),
        );
        _loadData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                letter.glyph,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4976),
                ),
              ),
            ),
            if (isMastered)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

