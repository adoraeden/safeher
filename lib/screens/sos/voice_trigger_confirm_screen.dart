import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../services/sos_countdown_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'sos_active_screen.dart';

/// Confirmation screen shown when an automatic SOS trigger fires (voice or shake).
/// Uses [SosCountdownService] as the single source of truth for the countdown so
/// that the in-app display, the notification, and cancellation are always in sync.
class VoiceTriggerConfirmScreen extends StatefulWidget {
  final String? detectedPhrase;
  final String source;

  const VoiceTriggerConfirmScreen({
    super.key,
    this.detectedPhrase,
    this.source = 'voice',
  });

  @override
  State<VoiceTriggerConfirmScreen> createState() =>
      _VoiceTriggerConfirmScreenState();
}

class _VoiceTriggerConfirmScreenState
    extends State<VoiceTriggerConfirmScreen> {
  // 8-second countdown — shared constant so UI always matches service.
  int _secondsLeft = SosCountdownService.sosCountdownSeconds;

  StreamSubscription<int>? _tickSub;
  StreamSubscription<void>? _cancelledSub;
  StreamSubscription<dynamic>? _activatedSub;
  StreamSubscription<void>? _notificationCancelSub;

  bool _isTriggering = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    // Sync with countdown service
    final countdown = SosCountdownService();
    _secondsLeft = countdown.secondsLeft;

    _tickSub = countdown.onTick.listen((secs) {
      if (mounted) setState(() => _secondsLeft = secs);
    });

    _cancelledSub = countdown.onCancelled.listen((_) {
      if (mounted && !_handled) {
        _handled = true;
        Navigator.pop(context);
      }
    });

    _activatedSub = countdown.onActivated.listen((event) async {
      if (!mounted || _handled) return;
      _handled = true;
      setState(() => _isTriggering = true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SosActiveScreen(event: event)),
        );
      }
    });

    // Also handle "Cancel SOS" tapped directly on the notification
    _notificationCancelSub = NotificationService().onSosCancelRequested.listen((_) {
      // SosCountdownService.cancel() is already called by NotificationService._onNotificationResponse
      // This listener is just a safety net for any remaining local cancel logic.
      if (mounted && !_handled) {
        _handled = true;
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _cancelledSub?.cancel();
    _activatedSub?.cancel();
    _notificationCancelSub?.cancel();
    super.dispose();
  }

  Future<void> _cancelFromButton() async {
    if (_handled) return;
    _handled = true;
    await SosCountdownService().cancel();
    if (mounted) Navigator.pop(context);
  }

  String get _headline {
    if (widget.source == 'shake') return 'Shake Trigger Detected';
    if (widget.detectedPhrase != null) return 'Emergency Phrase Detected';
    return 'Emergency Trigger Detected';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.source == 'shake'
                        ? Icons.vibration
                        : Icons.record_voice_over,
                    size: 56,
                    color: AppColors.dangerLight,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _headline,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.detectedPhrase != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '"${widget.detectedPhrase}"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerLight,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isTriggering
                        ? 'Activating central SOS…'
                        : 'Sending SOS in $_secondsLeft seconds…',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!_isTriggering)
                    ElevatedButton(
                      onPressed: _cancelFromButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Not an emergency — Cancel SOS'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
