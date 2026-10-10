import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// Normalizes text and matches trigger phrases with fuzzy/phonetic tolerance.
class VoiceTriggerMatcher {
  static String normalize(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll(
          RegExp(r'''[.,\/#!$%\^\&\*;:{}=\-_`~()?"''""\[\]\\]'''),
          ' ',
        )
        .replaceAll(RegExp('[\u2018\u2019\u201C\u201D]'), ' ')
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

    final heardWords = heardNorm.split(' ').where((w) => w.isNotEmpty).toList();
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
    final phraseWords = variant.split(' ').where((w) => w.isNotEmpty).toList();
    if (phraseWords.isEmpty) return false;

    // Single-word trigger — only match in short utterances to avoid false alarms.
    if (phraseWords.length == 1) {
      final target = phraseWords.first;
      if (heardWords.length > 5) return false;
      return heardWords.any(
        (w) => w == target || stemWord(w) == target || _isWordClose(w, target),
      );
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

/// Controls the Android foreground service (VoiceGuardListenService) that
/// listens for the emergency phrase using Vosk, even when the app is in the
/// background or the screen is off.
class VoiceGuardService {
  VoiceGuardService._internal();
  static final VoiceGuardService _instance = VoiceGuardService._internal();
  factory VoiceGuardService() => _instance;

  static const MethodChannel _channel = MethodChannel(
    'com.safeher.women_safety/voice_guard',
  );
  static const EventChannel _events = EventChannel(
    'com.safeher.women_safety/voice_guard_events',
  );

  StreamSubscription<dynamic>? _eventSub;

  bool _isActive = false;
  bool _isListening = false;
  bool _isPaused = false;

  List<String> _triggerPhrases = [];
  // Every spelling variant we send to the recognizer -> the saved phrase it belongs to.
  final Map<String, String> _variantToPhrase = {};

  void Function(String matchedPhrase)? _onTriggerDetected;
  void Function(String status)? _onStatusChanged;
  void Function(String errorMessage)? _onError;

  DateTime? _lastTriggerTime;
  // Short live status text shown on the Voice Guard card (for testing).
  final ValueNotifier<String> debugInfo = ValueNotifier<String>('');

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
    final cleaned = triggerPhrases
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      debugPrint('[VoiceGuard] Start aborted: triggerPhrases is empty');
      return false;
    }

    _onTriggerDetected = onTriggerDetected;
    _onStatusChanged = onStatusChanged;
    _onError = onError;

    // Already running with the same phrases: just reconnect the callbacks
    // (for example after the dashboard screen was rebuilt).
    if (_isActive && listEquals(cleaned, _triggerPhrases)) {
      debugPrint('[VoiceGuard] Already running - callbacks reconnected');
      if (_isPaused) resume();
      return true;
    }

    if (_isActive) {
      stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _triggerPhrases = cleaned;
    _variantToPhrase.clear();
    for (final phrase in cleaned) {
      for (final variant in VoiceTriggerMatcher.generateVariants(phrase)) {
        _variantToPhrase.putIfAbsent(variant, () => phrase);
      }
    }

    // Microphone permission (this shows the Android permission popup if needed).
    bool granted = false;
    try {
      final recorder = AudioRecorder();
      granted = await recorder.hasPermission();
      await recorder.dispose();
    } catch (e) {
      debugPrint('[VoiceGuard] Permission check failed: $e');
    }
    if (!granted) {
      _onError?.call('Microphone permission denied');
      return false;
    }

    _eventSub?.cancel();
    _eventSub = _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object e) => debugPrint('[VoiceGuard] Event stream error: $e'),
    );

    try {
      await _channel.invokeMethod('start', {
        'phrases': _variantToPhrase.keys.toList(),
      });
    } on PlatformException catch (e) {
      debugPrint('[VoiceGuard] Could not start service: ${e.message}');
      _onError?.call('Could not start Voice Guard: ${e.message}');
      _eventSub?.cancel();
      _eventSub = null;
      return false;
    }

    _isActive = true;
    _isPaused = false;
    _isListening = false;
    debugPrint('[VoiceGuard] Service started with phrases: $_triggerPhrases');
    return true;
  }

  void pause() {
    if (!_isActive) return;
    debugPrint('[VoiceGuard] Pausing');
    _isPaused = true;
    _isListening = false;
    _invoke('pause');
  }

  void resume() {
    if (!_isActive || !_isPaused) return;
    debugPrint('[VoiceGuard] Resuming');
    _isPaused = false;
    _invoke('resume');
  }

  void stop() {
    debugPrint('[VoiceGuard] Stopping and releasing microphone');
    _isActive = false;
    _isListening = false;
    _isPaused = false;
    _invoke('stop');
    _eventSub?.cancel();
    _eventSub = null;
    _onStatusChanged?.call('stopped');
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      debugPrint('[VoiceGuard] "$method" failed: $e');
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type']?.toString() ?? '';
    final value = event['value']?.toString() ?? '';

    switch (type) {
      case 'status':
        debugPrint('[VoiceGuard] Status: $value');
        debugInfo.value = 'Status: $value';
        if (value == 'listening') {
          _isListening = true;
          _onStatusChanged?.call('listening');
        } else if (value == 'paused') {
          _isListening = false;
        } else if (value == 'stopped') {
          // Android closed the service (for example SafeHer was swiped away).
          _isActive = false;
          _isListening = false;
          _isPaused = false;
          _eventSub?.cancel();
          _eventSub = null;
          _onStatusChanged?.call('stopped');
          _onError?.call(
            'Voice Guard stopped because SafeHer was closed. Turn it on again.',
          );
        }
        break;

      case 'heard':
        debugInfo.value = 'Heard: $value';
        break;

      case 'error':
        debugPrint('[VoiceGuard] Native error: $value');
        debugInfo.value = 'Error: $value';
        _isActive = false;
        _isListening = false;
        _isPaused = false;
        _invoke('stop');
        _eventSub?.cancel();
        _eventSub = null;
        _onStatusChanged?.call('error');
        _onError?.call('Voice Guard problem: $value');
        break;

      case 'phrase':
        _handlePhrase(value);
        break;
    }
  }

  void _handlePhrase(String heard) {
    if (!_isActive || _isPaused) return;

    // Prevent duplicate triggers within 5 seconds of the last one.
    final now = DateTime.now();
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!).inMilliseconds < 5000) {
      return;
    }
    _lastTriggerTime = now;

    final matched = _phraseFor(heard);
    debugPrint(
      '[VoiceGuard] *** TRIGGER DETECTED: "$matched" (heard "$heard") *** pausing for countdown',
    );
    pause();
    _onTriggerDetected?.call(matched);
  }

  String _phraseFor(String heard) {
    final h = VoiceTriggerMatcher.normalize(heard);
    for (final entry in _variantToPhrase.entries) {
      if (h.contains(entry.key)) return entry.value;
    }
    return VoiceTriggerMatcher.findMatch(heard, _triggerPhrases) ??
        (_triggerPhrases.isNotEmpty ? _triggerPhrases.first : heard);
  }
}
