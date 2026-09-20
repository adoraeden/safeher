import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class VoiceGuardService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isActive = false;
  List<String> _triggerPhrases = [];
  void Function()? _onTriggerDetected;

  bool get isActive => _isActive;

  Future<bool> start({
    required List<String> triggerPhrases,
    required void Function() onTriggerDetected,
  }) async {
    _triggerPhrases = triggerPhrases
        .map((p) => p.toLowerCase().trim())
        .where((p) => p.isNotEmpty)
        .toList();
    _onTriggerDetected = onTriggerDetected;

    if (_triggerPhrases.isEmpty) return false;

    final available = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );
    if (!available) return false;

    _isActive = true;
    _listenCycle();
    return true;
  }

  void _handleStatus(String status) {
    if (_isActive && (status == 'done' || status == 'notListening')) {
      _listenCycle();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    // Transient (silence, no speech detected) — the status listener above
    // restarts the cycle, so a single failed attempt doesn't disable Voice Guard.
  }

  void _listenCycle() {
    if (!_isActive) return;
    _speech.listen(
      onResult: _handleResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
  }

  void _handleResult(SpeechRecognitionResult result) {
    final heard = result.recognizedWords.toLowerCase();
    if (heard.isEmpty) return;
    final matched = _triggerPhrases.any((phrase) => _fuzzyMatch(heard, phrase));
    if (matched) {
      stop();
      _onTriggerDetected?.call();
    }
  }

  /// True if at least 70% of the trigger phrase's words appear anywhere in
  /// what was heard — forgiving of real speech-recognition mis-transcription,
  /// while still requiring most of a distinctive phrase to actually be said.
  bool _fuzzyMatch(String heard, String phrase) {
    final phraseWords = phrase
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (phraseWords.isEmpty) return false;
    final heardWords = heard.split(RegExp(r'\s+')).toSet();
    final matchedCount = phraseWords
        .where((w) => heardWords.contains(w))
        .length;
    return matchedCount / phraseWords.length >= 0.7;
  }

  void stop() {
    _isActive = false;
    _speech.stop();
  }
}
