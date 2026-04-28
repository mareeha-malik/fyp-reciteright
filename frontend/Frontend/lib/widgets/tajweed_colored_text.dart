import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TajweedColoredText extends StatelessWidget {
  final String arabicText;
  final List<dynamic> wordResults;
  final bool showLabels;
  final bool interactive;

  const TajweedColoredText({
    Key? key,
    required this.arabicText,
    required this.wordResults,
    this.showLabels = true,
    this.interactive = true,
  }) : super(key: key);

  List<String> _splitWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  Map<String, dynamic> _getWordData(String word, int index) {
    if (index < wordResults.length) {
      return wordResults[index];
    }
    return {};
  }

  Color _getColorFromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF' + hex;
    }
    return Color(int.parse(hex, radix: 16));
  }

  Map<String, dynamic>? _getPrimaryRule(Map<String, dynamic> wordData) {
    final rules = wordData['tajweed_rules'] as List<dynamic>?;
    if (rules == null || rules.isEmpty) return null;

    final rulePriority = {
      'Madd Tabee\'i': 1,
      'Madd Muttasil': 1,
      'Madd Munfasil': 1,
      'Madd Lazim': 1,
      'Ghunnah': 2,
      'Qalqalah Major': 3,
      'Qalqalah Minor': 3,
      'Ikhfa': 4,
      'Idgham with Ghunnah': 5,
      'Idgham without Ghunnah': 5,
      'Iqlab': 6,
      'Izhar': 7,
      'Shadda': 8,
      'Tafkhim': 9,
      'Sukoon': 10,
    };

    rules.sort((a, b) {
      final pA = rulePriority[a['rule']] ?? 99;
      final pB = rulePriority[b['rule']] ?? 99;
      return pA.compareTo(pB);
    });

    return rules.first;
  }

  String _getRuleLabel(String ruleName) {
    if (ruleName.contains('Madd')) return 'Madd';
    if (ruleName.contains('Qalqalah')) return 'Qalq';
    if (ruleName.contains('Idgham')) return 'Idgh';
    if (ruleName.contains('Ghunnah')) return 'Ghun';
    if (ruleName.contains('Ikhfa')) return 'Ikhfa';
    if (ruleName.contains('Iqlab')) return 'Iqlab';
    if (ruleName.contains('Izhar')) return 'Izhar';
    if (ruleName.contains('Shadda')) return 'Shad';
    if (ruleName.contains('Tafkhim')) return 'Tafk';
    return ruleName;
  }

  void _showRuleDialog(BuildContext context, String word, Map<String, dynamic> rule) {
    if (!interactive) return;

    String ruleName = rule['rule'] ?? 'Unknown Rule';
    Color color = rule['color'] != null ? _getColorFromHex(rule['color']) : Colors.black;

    String instructions = "Practice this rule properly.";
    String duration = "";

    if (ruleName.contains("Madd Tabee'i")) {
      duration = "2 counts";
      instructions = "Extend the vowel naturally.";
    } else if (ruleName.contains("Madd Muttasil") || ruleName.contains("Madd Munfasil")) {
      duration = "4-5 counts";
      instructions = "Extend for 4 to 5 counts.";
    } else if (ruleName.contains("Madd Lazim")) {
      duration = "6 counts";
      instructions = "Obligatory extension for 6 counts.";
    } else if (ruleName.contains("Ghunnah")) {
      duration = "2 counts";
      instructions = "Nasal sound for 2 counts.";
    } else if (ruleName.contains("Qalqalah")) {
      instructions = "Slight bounce or echo sound.";
    } else if (ruleName.contains("Ikhfa")) {
      duration = "2 counts";
      instructions = "Hide the noon sound partially with nasalization.";
    } else if (ruleName.contains("Idgham with Ghunnah")) {
      duration = "2 counts";
      instructions = "Merge into next letter with nasal sound.";
    } else if (ruleName.contains("Idgham without Ghunnah")) {
      instructions = "Merge silently without nasal sound.";
    } else if (ruleName.contains("Izhar")) {
      instructions = "Clear pronunciation, no nasal.";
    } else if (ruleName.contains("Iqlab")) {
      duration = "2 counts";
      instructions = "Convert to Meem sound.";
    } else if (ruleName.contains("Shadda")) {
      instructions = "Double the letter emphasis.";
    } else if (ruleName.contains("Tafkhim")) {
      instructions = "Heavy full-mouth pronunciation.";
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word,
                style: GoogleFonts.scheherazadeNew(fontSize: 36),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Text(ruleName, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 15),
              if (duration.isNotEmpty)
                Text(
                  "Duration: $duration",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              SizedBox(height: 10),
              Text(
                "How to do it:\n$instructions",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = _splitWords(arabicText);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 12,
        children: List.generate(words.length, (index) {
          final word = words[index];
          final data = _getWordData(word, index);
          final primaryRule = _getPrimaryRule(data);

          Color ruleColor = Colors.transparent;
          String ruleLabel = "";

          if (primaryRule != null) {
            ruleColor = _getColorFromHex(primaryRule['color'] ?? '#1a1a1a');
            ruleLabel = _getRuleLabel(primaryRule['rule'] ?? '');
          }

          return GestureDetector(
            onTap: () {
              if (primaryRule != null) {
                _showRuleDialog(context, word, primaryRule);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word,
                  style: GoogleFonts.scheherazadeNew(fontSize: 26, color: Colors.black87),
                  textDirection: TextDirection.rtl,
                ),
                if (ruleColor != Colors.transparent)
                  Container(
                    height: 3,
                    width: 40,
                    margin: EdgeInsets.only(top: 2),
                    color: ruleColor,
                  ),
                if (showLabels && ruleLabel.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      ruleLabel,
                      style: TextStyle(fontSize: 9, color: ruleColor, fontWeight: FontWeight.bold),
                    ),
                  )
              ],
            ),
          );
        }),
      ),
    );
  }
}

