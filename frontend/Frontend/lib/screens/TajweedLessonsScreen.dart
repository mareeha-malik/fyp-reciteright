import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tajweed_lesson.dart';
import './LessonDetailScreen.dart';

class TajweedLessonsScreen extends StatefulWidget {
  const TajweedLessonsScreen({Key? key}) : super(key: key);

  @override
  State<TajweedLessonsScreen> createState() => _TajweedLessonsScreenState();
}

class _TajweedLessonsScreenState extends State<TajweedLessonsScreen> {
  SharedPreferences? _prefs;
  bool _isPrefsReady = false;
  int _completedLessonsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (var lesson in lessons) {
      final isCompleted = prefs.getBool('lesson_${lesson.id}_completed') ?? false;
      if (isCompleted) count++;
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _isPrefsReady = true;
      _completedLessonsCount = count;
    });
  }

  bool _isLessonCompleted(String lessonId) {
    return _prefs?.getBool('lesson_${lessonId}_completed') ?? false;
  }

  int _getLessonScore(String lessonId) {
    return _prefs?.getInt('lesson_${lessonId}_score') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Tajweed Lessons',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E4976),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress header card
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E4976), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '🕌',
                      style: TextStyle(fontSize: 28),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your Tajweed Journey',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$_completedLessonsCount of ${lessons.length} lessons completed',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        lessons.isEmpty ? 0 : (_completedLessonsCount / lessons.length),
                    minHeight: 8,
                    backgroundColor: Colors.white30,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_isPrefsReady)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          // Lessons list
          ...List.generate(lessons.length, (index) {
            final lesson = lessons[index];
            final isCompleted = _isLessonCompleted(lesson.id);
            final score = _getLessonScore(lesson.id);

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonDetailScreen(lesson: lesson),
                  ),
                );
                _loadProgress();
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          // Left colored strip
                          Container(
                            width: 6,
                            height: 160,
                            decoration: BoxDecoration(
                              color: lesson.color,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Icon circle
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: lesson.color.withValues(alpha: 0.2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            lesson.icon,
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lesson.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              lesson.arabicTitle,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lesson.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Duration chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 12,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              lesson.duration,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status button
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? Colors.green[100]
                                              : lesson.color.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isCompleted ? '✓ Completed' : 'Start →',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isCompleted
                                                ? Colors.green[700]
                                                : lesson.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isCompleted)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: score / 100,
                                          minHeight: 4,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            lesson.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Completed overlay (if locked in future)
                      // Removed dead code
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


