import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Controls the native Android microphone foreground service.
///
/// IMPORTANT — Android background limitation:
/// The [stt.SpeechToText] plugin relies on Android's SpeechRecognizer API,
/// which requires a live Activity context. When the user presses Home, Android
/// may eventually suspend the Flutter Activity (though not kill the process if
/// a foreground service is running). While the process stays alive, speech
/// recognition continues. However, if Android force-stops or kills the process,
/// recognition will stop. This is an OS-level restriction that cannot be
/// bypassed by the app. The native foreground microphone service keeps the
/// process at elevated priority, making it much less likely to be killed.
class ForegroundServiceHelper {
  static const _channel =
      MethodChannel('com.safeher.women_safety/voice_guard_service');

  static Future<void> startMicrophoneService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService');
      debugPrint(
          '[ForegroundServiceHelper] Native microphone foreground service started');
    } catch (e) {
      debugPrint(
          '[ForegroundServiceHelper] Failed to start native foreground service: $e');
    }
  }

  static Future<void> stopMicrophoneService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
      debugPrint(
          '[ForegroundServiceHelper] Native microphone foreground service stopped');
    } catch (e) {
      debugPrint(
          '[ForegroundServiceHelper] Failed to stop native foreground service: $e');
    }
  }
}

/// Normalizes text and matches trigger phrases with fuzzy/phonetic tolerance.
class VoiceTriggerMatcher {
  static String normalize(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll(
            RegExp(r'''[.,\/#!$%\^\&\*;:{}=\-_`~()?"''""\[\]\\]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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

  /// Phonetic / homophonic variants for "SafeHer" and similar app-specific words.
  static List<String> generateVariants(String phrase) {
    final norm = normalize(phrase);
    if (norm.isEmpty) return [];

    final variants = <String>{norm};

    const safeHerEquivalents = [
      'safeher',
      'safe her',
      'save her',
      'safer',
      'safe here',
      'safe hair',
      'save here',
      'safe hear',
    ];

    for (final eq in safeHerEquivalents) {
      if (norm.contains(eq)) {
        for (final target in safeHerEquivalents) {
          variants.add(norm.replaceAll(eq, target));
        }
      }
    }

    return variants.toList();
  }

  /// Returns the matched trigger phrase string, or null.
  static String? findMatch(String heardText, List<String> triggerPhrases) {
    final heardNorm = normalize(heardText);
    if (heardNorm.isEmpty) return null;

    final heardWords =
        heardNorm.split(' ').where((w) => w.isNotEmpty).toList();
    if (heardWords.isEmpty) return null;

    for (final phrase in triggerPhrases) {
      final variants = generateVariants(phrase);
      for (final variant in variants) {
        if (_matchSingleVariant(heardNorm, heardWords, variant)) {
          return phrase;
        }
      }
    }

    return null;
  }

  static bool matches(String heardText, List<String> triggerPhrases) {
    return findMatch(heardText, triggerPhrases) != null;
  }

  static bool _matchSingleVariant(
    String heardNorm,
    List<String> heardWords,
    String variant,
  ) {
    final phraseWords =
        variant.split(' ').where((w) => w.isNotEmpty).toList();
    if (phraseWords.isEmpty) return false;

    // Single-word trigger — only match in short utterances to avoid false alarms.
    if (phraseWords.length == 1) {
      final target = phraseWords.first;
      if (heardWords.length > 5) return false;
      return heardWords
          .any((w) => w == target || stemWord(w) == target || _isWordClose(w, target));
    }

    // Direct exact contiguous match.
    final pattern = RegExp('(^|\\s)${RegExp.escape(variant)}(\$|\\s)');
    if (pattern.hasMatch(heardNorm)) return true;

    // Sliding window with 1-word tolerance.
    final phraseLen = phraseWords.length;
    for (
      int wSize = phraseLen;
      wSize <= phraseLen + 1 && wSize <= heardWords.length;
      wSize++
    ) {
      for (int i = 0; i <= heardWords.length - wSize; i++) {
        final window = heardWords.sublist(i, i + wSize);
        if (_windowMatchesPhrase(window, phraseWords)) return true;
      }
    }

    return false;
  }

  static bool _windowMatchesPhrase(
    List<String> window,
    List<String> phraseWords,
  ) {
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
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}

class VoiceGuardService {
  VoiceGuardService._internal();
  static final VoiceGuardService _instance = VoiceGuardService._internal();
  factory VoiceGuardService() => _instance;

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isActive = false;
  bool _isListening = false;
  bool _isStarting = false;
  bool _isPaused = false;

  String? _preferredLocaleId;
  List<String> _triggerPhrases = [];

  void Function(String matchedPhrase)? _onTriggerDetected;
  void Function(String status)? _onStatusChanged;
  void Function(String errorMessage)? _onError;

  Timer? _restartDebounceTimer;
  Timer? _watchdogTimer;

  DateTime? _lastTriggerTime;

  // Consecutive error tracking — resets on each successful 'listening' status.
  int _consecutiveErrorCount = 0;
  static const int _maxConsecutiveErrors = 15;

  // ── Public state getters ──────────────────────────────────────────────────
  bool get isActive => _isActive;
  bool get isListening => _isListening;
  bool get isPaused => _isPaused;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> start({
    required List<String> triggerPhrases,
    required void Function(String matchedPhrase) onTriggerDetected,
    void Function(String status)? onStatusChanged,
    void Function(String errorMessage)? onError,
  }) async {
    // If already running, stop cleanly before restarting.
    if (_isActive) {
      stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _triggerPhrases = triggerPhrases
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    _onTriggerDetected = onTriggerDetected;
    _onStatusChanged = onStatusChanged;
    _onError = onError;
    _isPaused = false;
    _consecutiveErrorCount = 0;

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

      if (available) {
        final locales = await _speech.locales();
        // Prefer en_IN for Indian users, then any English, then first available.
        final enLocale = locales.firstWhere(
          (l) => l.localeId.startsWith('en_IN'),
          orElse: () => locales.firstWhere(
            (l) => l.localeId.startsWith('en_'),
            orElse: () => locales.isNotEmpty
                ? locales.first
                : stt.LocaleName('en_US', 'English'),
          ),
        );
        _preferredLocaleId = enLocale.localeId;
        debugPrint(
            '[VoiceGuard] Selected speech recognition locale: $_preferredLocaleId');
      }
    } catch (e) {
      debugPrint('[VoiceGuard] Initialization exception: $e');
      _onError?.call('Microphone or speech service unavailable: $e');
      return false;
    }

    if (!available) {
      debugPrint('[VoiceGuard] Speech recognition not available');
      _onError?.call(
          'Microphone permission denied or speech service not available');
      return false;
    }

    // Start native Android foreground service to keep process alive in background.
    await ForegroundServiceHelper.startMicrophoneService();

    _isActive = true;
    _startListening();
    _startWatchdog();
    return true;
  }

  void pause() {
    if (!_isActive) return;
    debugPrint('[VoiceGuard] Pausing listening');
    _isPaused = true;
    _restartDebounceTimer?.cancel();
    _speech.stop();
    _isListening = false;
  }

  void resume() {
    if (!_isActive || !_isPaused) return;
    debugPrint('[VoiceGuard] Resuming listening');
    _isPaused = false;
    _consecutiveErrorCount = 0;
    _scheduleRestart(delayMillis: 300);
  }

  void stop() {
    debugPrint('[VoiceGuard] Stopping and releasing microphone');
    _isActive = false;
    _isListening = false;
    _isStarting = false;
    _isPaused = false;
    _restartDebounceTimer?.cancel();
    _watchdogTimer?.cancel();
    _speech.stop();
    _onStatusChanged?.call('stopped');
    ForegroundServiceHelper.stopMicrophoneService();
  }

  // ── Internal lifecycle ────────────────────────────────────────────────────

  /// Watchdog that rescues a silently-stopped recognizer.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isActive || _isPaused) return;
      if (!_speech.isListening && !_isStarting) {
        debugPrint(
            '[VoiceGuard Watchdog] Recognizer is idle but guard is active — restarting');
        _startListening();
      }
    });
  }

  void _startListening() async {
    if (!_isActive || _isPaused || _isStarting) return;
    if (_speech.isListening) return;

    _isStarting = true;
    _restartDebounceTimer?.cancel();

    debugPrint('[VoiceGuard] Starting listen session...');
    try {
      // ── Listen parameters ────────────────────────────────────────────────
      // listenFor: 60 s  → fewer session restarts = fewer OS beep sounds
      // pauseFor:  6 s   → tolerates silence gaps without killing session
      // listenMode: dictation → keeps session open through multiple words
      // partialResults: true → catch phrase even if final result is delayed
      // cancelOnError: false → let our handler decide what to do on error
      final options = stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 6),
        listenFor: const Duration(seconds: 60),
        localeId: _preferredLocaleId,
      );

      await _speech.listen(
        onResult: _handleResult,
        listenOptions: options,
      );
    } catch (e) {
      debugPrint('[VoiceGuard] Error starting listen: $e');
      _scheduleRestart(delayMillis: 500);
    } finally {
      _isStarting = false;
    }
  }

  void _handleStatus(String status) {
    debugPrint('[VoiceGuard] Status: $status');
    switch (status) {
      case 'listening':
        _isListening = true;
        _consecutiveErrorCount = 0;
        _onStatusChanged?.call('listening');
        break;
      case 'notListening':
      case 'done':
        _isListening = false;
        _onStatusChanged?.call(status);
        // Session ended naturally (e.g. listenFor or pauseFor expired).
        // Restart to keep listening continuously.
        if (_isActive && !_isPaused) {
          // Small delay to let the recognizer fully release resources.
          _scheduleRestart(delayMillis: 200);
        }
        break;
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint(
        '[VoiceGuard] Error: ${error.errorMsg} (permanent=${error.permanent})');
    if (!_isActive || _isPaused) return;

    // NOTE: On Android, error.permanent is ALWAYS true regardless of severity.
    // We therefore NEVER use it to decide whether to shut down.
    _isListening = false;

    final msg = error.errorMsg.toLowerCase();

    // Normal silence / no speech detected → short delay restart.
    if (msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('timeout')) {
      _scheduleRestart(delayMillis: 200);
      return;
    }

    // Hardware busy / another app took the mic → wait longer.
    if (msg.contains('busy') || msg.contains('client')) {
      _scheduleRestart(delayMillis: 800);
      return;
    }

    // Audio / network / server errors — transient, backoff.
    _consecutiveErrorCount++;
    if (_consecutiveErrorCount > _maxConsecutiveErrors) {
      debugPrint(
          '[VoiceGuard] Many consecutive errors ($_consecutiveErrorCount) — longer backoff, then reset');
      _consecutiveErrorCount = 0;
      _scheduleRestart(delayMillis: 3000);
    } else {
      final delay = 300 + (_consecutiveErrorCount * 100).clamp(0, 1000);
      _scheduleRestart(delayMillis: delay);
    }
  }

  void _scheduleRestart({int delayMillis = 200}) {
    if (!_isActive || _isPaused) return;
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = Timer(Duration(milliseconds: delayMillis), () {
      if (_isActive && !_isPaused && !_speech.isListening && !_isStarting) {
        _startListening();
      }
    });
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!_isActive || _isPaused) return;
    if (result.recognizedWords.isEmpty) return;

    // Prevent duplicate triggers within 5 seconds of the last confirmed trigger.
    final now = DateTime.now();
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!).inMilliseconds < 5000) {
      return;
    }

    // Collect the primary transcript + any alternatives.
    final candidates = <String>{result.recognizedWords};
    for (final alt in result.alternates) {
      if (alt.recognizedWords.isNotEmpty) {
        candidates.add(alt.recognizedWords);
      }
    }

    debugPrint(
        '[VoiceGuard] Transcript (final=${result.finalResult}): $candidates');

    String? matchedPhrase;
    for (final c in candidates) {
      final match = VoiceTriggerMatcher.findMatch(c, _triggerPhrases);
      if (match != null) {
        matchedPhrase = match;
        break;
      }
    }

    if (matchedPhrase != null) {
      _lastTriggerTime = now;
      debugPrint(
          '[VoiceGuard] *** TRIGGER DETECTED: "$matchedPhrase" *** pausing for countdown');
      pause();
      _onTriggerDetected?.call(matchedPhrase);
    }
  }
}
