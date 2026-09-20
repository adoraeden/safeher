import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/emergency_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'sos_active_screen.dart';

class VoiceTriggerConfirmScreen extends StatefulWidget {
  const VoiceTriggerConfirmScreen({super.key});

  @override
  State<VoiceTriggerConfirmScreen> createState() =>
      _VoiceTriggerConfirmScreenState();
}

class _VoiceTriggerConfirmScreenState extends State<VoiceTriggerConfirmScreen> {
  int _secondsLeft = 5;
  Timer? _timer;
  bool _cancelled = false;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _fireSos();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fireSos() async {
    if (_cancelled) return;
    setState(() => _isTriggering = true);
    try {
      final event = await EmergencyService().triggerSos();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SosActiveScreen(event: event)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voice-triggered SOS failed: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  void _cancel() {
    _cancelled = true;
    _timer?.cancel();
    Navigator.pop(context);
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
                  const Icon(
                    Icons.record_voice_over,
                    size: 48,
                    color: AppColors.dangerLight,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Trigger phrase detected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isTriggering
                        ? 'Sending SOS…'
                        : 'Sending SOS in $_secondsLeft…',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!_isTriggering)
                    ElevatedButton(
                      onPressed: _cancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                      child: const Text('Not an emergency — cancel'),
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
