import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../services/quran_lesson_service.dart';

class WordByWordWidget extends StatefulWidget {
  final List<QuranWord> words;

  const WordByWordWidget({
    Key? key,
    required this.words,
  }) : super(key: key);

  @override
  State<WordByWordWidget> createState() => _WordByWordWidgetState();
}

class _WordByWordWidgetState extends State<WordByWordWidget> {
  late AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _playingWordIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;

      if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _playingWordIndex = null;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String audioUrl, String index) async {
    try {
      if (!mounted) return;
      setState(() {
        _playingWordIndex = index;
        _isLoading = true;
      });

      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Error playing audio - gracefully handling
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _playingWordIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return Center(
        child: Text(
          'No words available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        textDirection: TextDirection.rtl,
        spacing: 8,
        runSpacing: 16,
        children: List.generate(widget.words.length, (index) {
          final word = widget.words[index];
          final wordKey = 'word_$index';
          final isPlaying = _playingWordIndex == wordKey;

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arabic text
                  Text(
                    word.arabic,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(
                    height: 12,
                    thickness: 0.5,
                    color: Colors.grey,
                  ),
                  // Translation
                  Text(
                    word.translation,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Transliteration
                  Text(
                    word.transliteration,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF546E7A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Play button if audio exists
                  if (word.audioUrl != null)
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading && isPlaying
                              ? null
                              : () => _playAudio(word.audioUrl!, wordKey),
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: isPlaying && _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.play_arrow,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

