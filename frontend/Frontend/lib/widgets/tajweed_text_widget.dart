import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TajweedRuleType {
  madd,
  ghunnah,
  qalqalah,
  ikhfa,
  idgham,
  izhar,
  shadda,
  sukoon,
  none,
}

class TajweedTextWidget extends StatelessWidget {
  final String arabicText;

  const TajweedTextWidget({
    super.key,
    required this.arabicText,
  });

  // Unicode constants
  static const String _fatha = '\u064E';
  static const String _damma = '\u064F';
  static const String _kasra = '\u0650';
  static const String _sukoon = '\u0652';
  static const String _shadda = '\u0651';
  static const String _maddSign = '\u0653';
  static const String _tanweenFath = '\u064B';
  static const String _tanweenDamm = '\u064C';
  static const String _tanweenKasr = '\u064D';
  static const String _alef = '\u0627';
  static const String _alefMaksura = '\u0649';
  static const String _noon = '\u0646';
  static const String _meem = '\u0645';

  static final RegExp _harakatRegex = RegExp(r'[\u064B-\u065F\u0670]');

  // Letter sets
  static const Set<String> _ikhfaLetters = {
    'ت', 'ث', 'ج', 'د', 'ذ', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ف', 'ق', 'ك',
  };

  static const Set<String> _idghamLetters = {'ي', 'ر', 'م', 'ل', 'و', 'ن'};
  static const Set<String> _izharLetters = {'ء', 'ه', 'ع', 'ح', 'غ', 'خ'};
  static const Set<String> _qalqalahLetters = {'ق', 'ط', 'ب', 'ج', 'د'};

  @override
  Widget build(BuildContext context) {
    final words = _splitWords(arabicText);
    final wordRules = <TajweedRuleType>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final nextWord = i < words.length - 1 ? words[i + 1] : null;
      final rule = _detectRuleForWord(word, nextWord);
      wordRules.add(rule);
    }

    // Get unique rules present in this ayah (excluding 'none')
    final presentRules = wordRules
        .where((r) => r != TajweedRuleType.none)
        .toSet()
        .toList()
        .cast<TajweedRuleType>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Word display
        Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: List<Widget>.generate(words.length, (index) {
                final word = words[index];
                final rule = wordRules[index];
                return _buildWordChip(context, word, rule);
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Legend showing active rules
        if (presentRules.isNotEmpty)
          _buildRuleLegend(presentRules),
      ],
    );
  }

  List<String> _splitWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  TajweedRuleType _detectRuleForWord(String word, String? nextWord) {
    // Rule detection order (precedence matters)

    // Check for Shadda first (high priority)
    if (word.contains(_shadda)) {
      // But if it's on noon or meem, it's Ghunnah
      if (word.contains('$_noon$_shadda') || word.contains('$_meem$_shadda')) {
        return TajweedRuleType.ghunnah;
      }
      return TajweedRuleType.shadda;
    }

    // Check for Qalqalah (letters with sukoon)
    if (_hasQalqalah(word)) {
      return TajweedRuleType.qalqalah;
    }

    // Check for Madd
    if (_hasMadd(word)) {
      return TajweedRuleType.madd;
    }

    final nextBaseLetter = _firstBaseLetter(nextWord ?? '');
    final hasNoonSakin = word.contains('$_noon$_sukoon');
    final hasTanween = word.contains(_tanweenFath) ||
        word.contains(_tanweenDamm) ||
        word.contains(_tanweenKasr);

    // Check for Idgham
    if ((hasNoonSakin || hasTanween) && _idghamLetters.contains(nextBaseLetter)) {
      return TajweedRuleType.idgham;
    }

    // Check for Izhar
    if ((hasNoonSakin || hasTanween) && _izharLetters.contains(nextBaseLetter)) {
      return TajweedRuleType.izhar;
    }

    // Check for Ikhfa
    if ((hasNoonSakin || hasTanween) && _ikhfaLetters.contains(nextBaseLetter)) {
      return TajweedRuleType.ikhfa;
    }

    // Check for Sukoon (not already classified)
    if (word.contains(_sukoon)) {
      return TajweedRuleType.sukoon;
    }

    return TajweedRuleType.none;
  }

  bool _hasMadd(String word) {
    // Maddah sign
    if (word.contains(_maddSign)) return true;

    // Alef after fatha
    if (RegExp('$_fatha$_alef').hasMatch(word)) return true;

    // Waw after damma
    if (RegExp('$_damma[و]').hasMatch(word)) return true;

    // Ya after kasra
    if (RegExp('$_kasra[ي]').hasMatch(word)) return true;

    // Alef Maksura (ى) at end
    if (word.endsWith(_alefMaksura)) return true;

    // Maa, Mee, Muu patterns
    if (word.contains('مَا') || word.contains('مِي') || word.contains('مُو')) {
      return true;
    }

    return false;
  }

  bool _hasQalqalah(String word) {
    // Check for qalqalah letters with sukoon
    for (final letter in _qalqalahLetters) {
      if (word.contains('$letter$_sukoon')) return true;
    }

    // Check for qalqalah letters at word end (waqf position)
    final cleanWord = word.replaceAll(_harakatRegex, '');
    if (cleanWord.isEmpty) return false;

    final lastChar = cleanWord[cleanWord.length - 1];
    if (_qalqalahLetters.contains(lastChar)) return true;

    return false;
  }

  String _firstBaseLetter(String text) {
    final cleaned = text.replaceAll(_harakatRegex, '');
    for (int i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (_isArabicLetter(ch)) {
        return ch;
      }
    }
    return '';
  }

  bool _isArabicLetter(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x0621 && code <= 0x064A;
  }

    Widget _buildWordChip(BuildContext context, String word, TajweedRuleType rule) {
    final color = _ruleColor(rule);
    final label = _ruleLabel(rule);

    return GestureDetector(
      onTap: () => _showRuleDialog(context, rule),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arabic text
            Text(
              word,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: rule != TajweedRuleType.none ? color : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),

            // Colored underline
            Container(
              height: 3,
              width: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            // Rule label (only if not "no rule")
            if (rule != TajweedRuleType.none)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.2,
                ),
              )
            else
              const SizedBox(height: 12), // Space placeholder for alignment
          ],
        ),
      ),
    );
    }

  Widget _buildRuleLegend(List<TajweedRuleType> rules) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: rules.map((rule) {
          final color = _ruleColor(rule);
          final label = _ruleLabel(rule);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _ruleColor(TajweedRuleType rule) {
    switch (rule) {
      case TajweedRuleType.madd:
        return const Color(0xFF1565C0); // dark blue
      case TajweedRuleType.ghunnah:
        return const Color(0xFF2E7D32); // dark green
      case TajweedRuleType.qalqalah:
        return const Color(0xFFE65100); // dark orange
      case TajweedRuleType.ikhfa:
        return const Color(0xFF6A1B9A); // purple
      case TajweedRuleType.idgham:
        return const Color(0xFFB71C1C); // dark red
      case TajweedRuleType.izhar:
        return const Color(0xFF00695C); // teal
      case TajweedRuleType.shadda:
        return const Color(0xFFF57F17); // amber
      case TajweedRuleType.sukoon:
        return const Color(0xFF37474F); // blue grey
      case TajweedRuleType.none:
        return const Color(0xFF212121); // near black
    }
  }

  String _ruleLabel(TajweedRuleType rule) {
    switch (rule) {
      case TajweedRuleType.madd:
        return 'Madd';
      case TajweedRuleType.ghunnah:
        return 'Ghunnah';
      case TajweedRuleType.qalqalah:
        return 'Qalqalah';
      case TajweedRuleType.ikhfa:
        return 'Ikhfa';
      case TajweedRuleType.idgham:
        return 'Idgham';
      case TajweedRuleType.izhar:
        return 'Izhar';
      case TajweedRuleType.shadda:
        return 'Shadda';
      case TajweedRuleType.sukoon:
        return 'Sukoon';
      case TajweedRuleType.none:
        return '';
    }
  }

  String _ruleExplanation(TajweedRuleType rule) {
    switch (rule) {
      case TajweedRuleType.madd:
        return 'Madd is elongation of sound. Extend the vowel naturally, usually 2 beats.';
      case TajweedRuleType.ghunnah:
        return 'Ghunnah is a nasal sound. Pronounce with a nasal tone from the nose, usually with noon or meem that has shadda.';
      case TajweedRuleType.qalqalah:
        return 'Qalqalah is a bouncing echo. When ق ط ب ج د have sukoon, pronounce with a slight bounce or echo.';
      case TajweedRuleType.ikhfa:
        return 'Ikhfa is partial concealment. Noon or tanween before ikhfa letters are pronounced with a hidden nasal sound.';
      case TajweedRuleType.idgham:
        return 'Idgham is merging. Noon saakin or tanween merges into the following letter with a nasal sound.';
      case TajweedRuleType.izhar:
        return 'Izhar is clear pronunciation. Noon saakin or tanween before throat letters must be pronounced clearly and separately.';
      case TajweedRuleType.shadda:
        return 'Shadda indicates emphasis or doubling. Pronounce the letter with emphasis.';
      case TajweedRuleType.sukoon:
        return 'Sukoon is the absence of vowel. The letter is pronounced without a vowel sound, stopping briefly.';
      case TajweedRuleType.none:
        return 'No special tajweed rule applies to this word.';
    }
  }

  void _showRuleDialog(BuildContext context, TajweedRuleType rule) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_ruleLabel(rule)),
          content: Text(_ruleExplanation(rule)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

