import re
import os

file_path = 'F:/ReciteRight-Clone/fyp-reciteright/frontend/Frontend/lib/screens/ComparisonResultsScreen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import for TajweedColoredText
import_stmt = "import 'package:tajweed_corrector/widgets/tajweed_colored_text.dart';\n"
if import_stmt not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_stmt)

# 2. Add teacher_feedback from comparisonResult
teacher_feedback_extract = """
      final teacherFeedback = Map<String, dynamic>.from(
        widget.comparisonResult['teacher_feedback'] as Map? ?? const {},
      );
      final correctTextText = widget.comparisonResult['correct_text'] as String? ?? '';
"""
if "final teacherFeedback = Map<String, dynamic>.from(" not in content:
    content = content.replace("final rulesBreakdown = Map<String, dynamic>.from(", teacher_feedback_extract + "      final rulesBreakdown = Map<String, dynamic>.from(")

# 3. Add Teacher Feedback and TajweedColoredText widgets at the beginning of body children
tajweed_ui = """
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
"""
if "NEW SECTION: Tajweed Colored Text" not in content:
    content = content.replace("// SECTION 1: Overall Score Card", tajweed_ui + "\n              // SECTION 1: Overall Score Card")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Widgets inserted correctly.")

