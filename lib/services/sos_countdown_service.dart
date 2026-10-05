import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/emergency_event.dart';
import 'emergency_service.dart';
import 'notification_service.dart';
import 'voice_guard_service.dart';

/// Single source of truth for the automatic SOS countdown (voice or shake).
///
/// Flow:
///   startCountdown() called
///   → notification shown immediately
///   → 7-second timer begins
///   → onTick emitted each second
///   → either cancel() cancels, or countdown reaches zero → triggerSos()
///
/// The countdown is NOT restarted or duplicated elsewhere.
class SosCountdownService {
  SosCountdownService._internal();
  static final SosCountdownService _instance = SosCountdownService._internal();
  factory SosCountdownService() => _instance;

  // ── Configuration ─────────────────────────────────────────────────────────
  /// 7-second countdown — single constant drives UI, notification, and timer.
  static const int sosCountdownSeconds = 7;

  // ── State ─────────────────────────────────────────────────────────────────
  int _secondsLeft = sosCountdownSeconds;
  bool _isActive = false;
  String? _detectedPhrase;
  String _source = 'voice';
  Timer? _timer;

  // ── Streams ───────────────────────────────────────────────────────────────
  final _tickController = StreamController<int>.broadcast();
  final _cancelledController = StreamController<void>.broadcast();
  final _activatedController = StreamController<EmergencyEvent>.broadcast();

  int get secondsLeft => _secondsLeft;
  bool get isActive => _isActive;
  String? get detectedPhrase => _detectedPhrase;
  String get source => _source;

  Stream<int> get onTick => _tickController.stream;
  Stream<void> get onCancelled => _cancelledController.stream;
  Stream<EmergencyEvent> get onActivated => _activatedController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts the 7-second countdown.
  /// Shows the SOS notification immediately and ticks every second.
  Future<void> startCountdown({
    required String source,
    String? phrase,
  }) async {
    if (_isActive) {
      debugPrint(
          '[SosCountdownService] Already active — ignoring duplicate start');
      return;
    }

    _isActive = true;
    _source = source;
    _detectedPhrase = phrase;
    _secondsLeft = sosCountdownSeconds;

    debugPrint(
        '[SosCountdownService] Starting ${sosCountdownSeconds}s countdown for $source (phrase: "$phrase")');

    // Pause Voice Guard during countdown so it does not self-trigger.
    VoiceGuardService().pause();

    // Show notification IMMEDIATELY — before the timer starts.
    await NotificationService().showSosTriggeredNotification(
      phrase: phrase,
      secondsLeft: _secondsLeft,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isActive) {
        timer.cancel();
        return;
      }

      _secondsLeft--;
      _tickController.add(_secondsLeft);

      if (_secondsLeft > 0) {
        // Update notification countdown text.
        await NotificationService().showSosTriggeredNotification(
          phrase: _detectedPhrase,
          secondsLeft: _secondsLeft,
        );
      } else {
        timer.cancel();
        _timer = null;
        await _completeCountdownAndTriggerSos();
      }
    });
  }

  /// Cancels the pending SOS countdown without triggering SOS.
  /// Voice Guard is resumed so protection continues.
  Future<void> cancel() async {
    if (!_isActive) return;
    debugPrint('[SosCountdownService] Cancelled by user');

    _isActive = false;
    _timer?.cancel();
    _timer = null;

    await NotificationService().clearSosNotification();
    VoiceGuardService().resume();

    _cancelledController.add(null);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _completeCountdownAndTriggerSos() async {
    if (!_isActive) return;
    _isActive = false;

    debugPrint(
        '[SosCountdownService] Countdown reached zero — dispatching SOS');

    await NotificationService().clearSosNotification();

    try {
      final event = await EmergencyService().triggerSos(
        source: _source,
        phrase: _detectedPhrase,
      );
      _activatedController.add(event);
    } catch (e) {
      debugPrint('[SosCountdownService] Failed to trigger SOS: $e');
    }
  }
}
