import re

file_path = 'F:/ReciteRight-Clone/fyp-reciteright/frontend/Frontend/lib/screens/AyahDisplayScreen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import for TajweedColoredText
import_stmt = "import 'package:tajweed_corrector/widgets/tajweed_colored_text.dart';\n"
if import_stmt not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_stmt)

# 2. Add detectTajweedFromText function globally
dart_function = """
List<Map<String, dynamic>> detectTajweedFromText(String arabicText) {
  final words = arabicText.trim().split(RegExp(r'\\s+')).where((w) => w.isNotEmpty).toList();
  List<Map<String, dynamic>> results = [];

  Map<String, dynamic> detectTajweedRules(String word, String nextWord) {
    List<Map<String, dynamic>> rules = [];

    if (RegExp(r'\\u064E\\u0627|\\u064F\\u0648|\\u0650\\u064A').hasMatch(word)) {
      rules.add({"rule": "Madd", "color": "#1565C0", "label": "Madd", "counts": 2});
    }

    if (RegExp(r'[\\u0646\\u0645]\\u0651').hasMatch(word)) {
      rules.add({"rule": "Ghunnah", "color": "#2E7D32", "label": "Ghun", "counts": 2});
    }

    if (RegExp(r'[\\u0642\\u0637\\u0628\\u062C\\u062F][\\u0652]').hasMatch(word) ||
        RegExp(r'[\\u0642\\u0637\\u0628\\u062C\\u062F]$').hasMatch(word)) {
      rules.add({"rule": "Qalqalah", "color": "#E65100", "label": "Qalq", "counts": 0});
    }

    if (word.contains('\\u0651')) {
      rules.add({"rule": "Shadda", "color": "#F57F17", "label": "Shad", "counts": 0});
    }

    final heavy = '\\u0635\\u0636\\u0637\\u0638\\u0642\\u063A\\u062E';
    if (word.split('').any((c) => heavy.contains(c))) {
      rules.add({"rule": "Tafkhim", "color": "#4E342E", "label": "Tafk", "counts": 0});
    }

    return rules.isNotEmpty ? rules.first : {"rule": "", "color": "#1a1a1a", "label": "", "counts": 0};
  }

  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    final nextWord = i < words.length - 1 ? words[i+1] : "";
    final primaryRule = detectTajweedRules(word, nextWord);

    results.add({
      "word": word,
      "status": "correct",
      "tajweed_rules": primaryRule["rule"] != "" ? [primaryRule] : [],
    });
  }
  return results;
}
"""
if "List<Map<String, dynamic>> detectTajweedFromText" not in content:
    content = content.replace("class AyahDisplayScreen extends StatefulWidget {", dart_function + "\nclass AyahDisplayScreen extends StatefulWidget {")

# 3. Replace the Text widgets that render Ayah texts with TajweedColoredText
content = re.sub(
    r"Text\(\s*ayahText,\s*textDirection:\s*TextDirection\.rtl,\s*textAlign:\s*TextAlign\.center,\s*maxLines:\s*null,\s*overflow:\s*TextOverflow\.visible,.*?,\s*\)",
    r"""TajweedColoredText(
              arabicText: ayahText,
              wordResults: detectTajweedFromText(ayahText),
              showLabels: true,
              interactive: true,
            )""",
    content,
    flags=re.DOTALL
)

content = re.sub(
    r"Text\(\s*ayah\['text'\]\s*as\s*String,\s*textDirection:\s*TextDirection\.rtl,\s*textAlign:\s*TextAlign\.center,.*?,\s*\)",
    r"""TajweedColoredText(
                          arabicText: ayah['text'] as String,
                          wordResults: detectTajweedFromText(ayah['text'] as String),
                          showLabels: true,
                          interactive: true,
                        )""",
    content,
    flags=re.DOTALL
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("AyahDisplayScreen updated.")

