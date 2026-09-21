import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Intelligent phrase normalization and matcher for Voice Guard.
class VoiceTriggerMatcher {
  /// Normalize text: lowercase, remove punctuation, collapse whitespace.
  static String normalize(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?"'’“”\[\]\\]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Simplifies common suffixes ('ed', 's', 'ing') to assist acoustic matching.
  static String stemWord(String word) {
    if (word.endsWith('ing') && word.length > 5) {
      return word.substring(0, word.length - 3);
    }
    if (word.endsWith('ed') && word.length > 4) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && word.length > 3 && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Expands trigger phrases with phonetic and compound word variants
  /// (e.g. "SafeHer" <-> "safe her" <-> "save her").
  static List<String> generateVariants(String phrase) {
    final norm = normalize(phrase);
    if (norm.isEmpty) return [];

    final variants = <String>{norm};

    if (norm.contains('safeher')) {
      variants.add(norm.replaceAll('safeher', 'safe her'));
      variants.add(norm.replaceAll('safeher', 'save her'));
    }
    if (norm.contains('safe her')) {
      variants.add(norm.replaceAll('safe her', 'safeher'));
      variants.add(norm.replaceAll('safe her', 'save her'));
    }
    if (norm.contains('save her')) {
      variants.add(norm.replaceAll('save her', 'safeher'));
      variants.add(norm.replaceAll('save her', 'safe her'));
    }

    return variants.toList();
  }

  /// Checks if [heardText] matches any phrase in [triggerPhrases].
  /// Matches contiguous word sequences, tolerates reasonable speech-recognition
  /// transcription variations, and guards against false positives in long conversations.
  static bool matches(String heardText, List<String> triggerPhrases) {
    final heardNorm = normalize(heardText);
    if (heardNorm.isEmpty) return false;

    final heardWords = heardNorm.split(' ').where((w) => w.isNotEmpty).toList();
    if (heardWords.isEmpty) return false;

    for (final phrase in triggerPhrases) {
      final variants = generateVariants(phrase);
      for (final variant in variants) {
        if (_matchSingleVariant(heardNorm, heardWords, variant)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _matchSingleVariant(
    String heardNorm,
    List<String> heardWords,
    String variant,
  ) {
    final phraseWords = variant.split(' ').where((w) => w.isNotEmpty).toList();
    if (phraseWords.isEmpty) return false;

    // 1. Single-word trigger handling
    if (phraseWords.length == 1) {
      final target = phraseWords.first;
      // In long casual utterances, ignore isolated single-word triggers to prevent false alarms
      if (heardWords.length > 4) {
        return false;
      }
      return heardWords.any((w) =>
          w == target ||
          stemWord(w) == target ||
          _isWordClose(w, target));
    }

    // 2. Direct contiguous exact substring with word boundaries (for multi-word phrases)
    final pattern = RegExp('(^|\\s)${RegExp.escape(variant)}(\$|\\s)');
    if (pattern.hasMatch(heardNorm)) {
      return true;
    }

    // 3. Multi-word triggers: sliding window search across heardWords
    final phraseLen = phraseWords.length;
    // Allow window size = phraseLen, or phraseLen + 1 (tolerates 1 filler word e.g. "please", "uh")
    for (int wSize = phraseLen;
        wSize <= phraseLen + 1 && wSize <= heardWords.length;
        wSize++) {
      for (int i = 0; i <= heardWords.length - wSize; i++) {
        final window = heardWords.sublist(i, i + wSize);
        if (_windowMatchesPhrase(window, phraseWords)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _windowMatchesPhrase(
      List<String> window, List<String> phraseWords) {
    int pIdx = 0;
    int mismatches = 0;

    for (int wIdx = 0; wIdx < window.length; wIdx++) {
      if (pIdx < phraseWords.length) {
        final wWord = window[wIdx];
        final pWord = phraseWords[pIdx];

        if (wWord == pWord ||
            stemWord(wWord) == stemWord(pWord) ||
            _isWordClose(wWord, pWord)) {
          pIdx++;
        } else {
          mismatches++;
        }
      } else {
        mismatches++;
      }
    }

    // All phrase words matched in sequence, with at most 1 filler/mismatched word in window
    return pIdx == phraseWords.length && mismatches <= 1;
  }

  static bool _isWordClose(String a, String b) {
    if (a == b) return true;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen < 4) return false;
    return _levenshtein(a, b) <= 1;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}

class VoiceGuardService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isActive = false;
  bool _isListening = false;
  bool _isStarting = false;
  List<String> _triggerPhrases = [];
  void Function()? _onTriggerDetected;
  void Function(String status)? _onStatusChanged;
  void Function(String errorMessage)? _onError;

  Timer? _restartDebounceTimer;
  DateTime? _lastTriggerTime;

  bool get isActive => _isActive;
  bool get isListening => _isListening;

  Future<bool> start({
    required List<String> triggerPhrases,
    required void Function() onTriggerDetected,
    void Function(String status)? onStatusChanged,
    void Function(String errorMessage)? onError,
  }) async {
    _triggerPhrases = triggerPhrases
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    _onTriggerDetected = onTriggerDetected;
    _onStatusChanged = onStatusChanged;
    _onError = onError;

    if (_triggerPhrases.isEmpty) {
      debugPrint('[VoiceGuard] Start aborted: triggerPhrases is empty');
      return false;
    }

    debugPrint('[VoiceGuard] Initializing with phrases: $_triggerPhrases');
    bool available = false;
    try {
      available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('[VoiceGuard] Initialization exception: $e');
      _onError?.call('Microphone or speech service unavailable: $e');
      return false;
    }

    if (!available) {
      debugPrint('[VoiceGuard] Speech recognition not available or permission denied');
      _onError?.call('Microphone permission denied or speech service not available');
      return false;
    }

    _isActive = true;
    _startListening();
    return true;
  }

  void _startListening() async {
    if (!_isActive || _isStarting || _speech.isListening) return;

    _isStarting = true;
    _restartDebounceTimer?.cancel();

    debugPrint('[VoiceGuard] Starting listen session in dictation mode...');
    try {
      final options = stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(seconds: 30),
      );

      await _speech.listen(
        onResult: _handleResult,
        listenOptions: options,
      );
    } catch (e) {
      debugPrint('[VoiceGuard] Error starting listen: $e');
      _scheduleRestart(delayMillis: 600);
    } finally {
      _isStarting = false;
    }
  }

  void _handleStatus(String status) {
    debugPrint('[VoiceGuard] Status update: $status');
    if (status == 'listening') {
      _isListening = true;
      _onStatusChanged?.call('listening');
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
      _onStatusChanged?.call(status);
      if (_isActive) {
        // Debounce restart so native audio hardware tears down cleanly (350ms delay)
        _scheduleRestart(delayMillis: 350);
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('[VoiceGuard] Recognition error: ${error.errorMsg} (permanent: ${error.permanent})');
    if (!_isActive) return;

    final msg = error.errorMsg.toLowerCase();
    final isTransient = !error.permanent ||
        msg.contains('timeout') ||
        msg.contains('no_match') ||
        msg.contains('busy') ||
        msg.contains('network') ||
        msg.contains('speech');

    if (isTransient) {
      // Recover automatically from silence, timeouts, or transient busy states
      final delay = msg.contains('busy') ? 600 : 350;
      _scheduleRestart(delayMillis: delay);
    } else {
      debugPrint('[VoiceGuard] Permanent error encountered: ${error.errorMsg}');
      _onError?.call(error.errorMsg);
    }
  }

  void _scheduleRestart({int delayMillis = 350}) {
    if (!_isActive) return;
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = Timer(Duration(milliseconds: delayMillis), () {
      if (_isActive && !_speech.isListening && !_isStarting) {
        debugPrint('[VoiceGuard] Executing scheduled restart cycle');
        _startListening();
      }
    });
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!_isActive) return;

    final now = DateTime.now();
    // Guard against repeated trigger callbacks for the same utterance
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!).inMilliseconds < 4000) {
      debugPrint('[VoiceGuard] Trigger cooldown active, ignoring result');
      return;
    }

    final candidates = <String>[];
    if (result.recognizedWords.isNotEmpty) {
      candidates.add(result.recognizedWords);
    }
    for (final alt in result.alternates) {
      if (alt.recognizedWords.isNotEmpty &&
          !candidates.contains(alt.recognizedWords)) {
        candidates.add(alt.recognizedWords);
      }
    }

    if (candidates.isEmpty) return;

    debugPrint('[VoiceGuard] Transcript (final: ${result.finalResult}, conf: ${result.confidence.toStringAsFixed(2)}): "$candidates"');

    final matched = candidates.any((c) => VoiceTriggerMatcher.matches(c, _triggerPhrases));
    if (matched) {
      _lastTriggerTime = now;
      debugPrint('[VoiceGuard] *** TRIGGER PHRASE CONFIRMED in $candidates! Activating SOS. ***');

      // Stop listening immediately to release microphone and prevent multiple activations
      stop();

      // Trigger existing SOS flow
      _onTriggerDetected?.call();
    }
  }

  void stop() {
    debugPrint('[VoiceGuard] Stopping Voice Guard and releasing microphone');
    _isActive = false;
    _isListening = false;
    _isStarting = false;
    _restartDebounceTimer?.cancel();
    _speech.stop();
    _onStatusChanged?.call('stopped');
  }
}
