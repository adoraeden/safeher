import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/voice_profile.dart';
import '../../services/voice_enrollment_service.dart';
import '../../services/voice_feature_extractor.dart';
import '../../services/voice_guard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../main/main_shell.dart';

class VoiceEnrollmentScreen extends StatefulWidget {
  final String phrase;
  final String? phraseId;
  final bool isOnboarding;

  const VoiceEnrollmentScreen({
    super.key,
    required this.phrase,
    this.phraseId,
    this.isOnboarding = false,
  });

  @override
  State<VoiceEnrollmentScreen> createState() => _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends State<VoiceEnrollmentScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _enrollmentService = VoiceEnrollmentService();

  final List<VoiceProfile> _captured = [];
  String? _currentPath;
  VoiceProfile? _pendingProfile;
  bool _isRecording = false;
  bool _hasReview = false;
  bool _isSaving = false;
  String? _validationError;

  static const int totalRecordings = 3;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    VoiceGuardService().pause();
    _player.setVolume(1.0);
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onLog.listen((message) {
      debugPrint('AudioPlayer log: $message');
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    VoiceGuardService().resume();
    super.dispose();
  }

  Future<void> _checkAndRequestPermission() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission && mounted) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Microphone Access Needed'),
          content: const Text(
            'SafeHer requires microphone access to enroll your voice profile for hands-free SOS. '
            'Without microphone access, Voice SOS cannot be set up.\n\n'
            'Manual SOS will remain fully functional at all times.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Set up later in Profile'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Grant Access'),
            ),
          ],
        ),
      );

      if (retry != true && mounted) {
        await _failAndGoToProfile('Microphone permission not granted');
      }
    }
  }

  Future<void> _startRecording() async {
    setState(() => _validationError = null);

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      await _checkAndRequestPermission();
      if (!await _recorder.hasPermission()) return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/enroll_${_captured.length}_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _currentPath = path;
        _hasReview = false;
        _pendingProfile = null;
        _validationError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Recording error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() => _isRecording = false);

      if (_currentPath == null) return;
      final file = File(_currentPath!);
      if (!await file.exists()) {
        setState(
          () => _validationError = 'Audio recording file was not found.',
        );
        return;
      }

      final bytes = await file.readAsBytes();
      // Audio bytes are strictly processed in-memory for acoustic pitch/energy and never stored as raw WAV
      final result = VoiceFeatureExtractor.validateAndExtractFromWav(bytes);

      if (!result.isValid || result.profile == null) {
        if (await file.exists()) await file.delete();
        setState(() {
          _hasReview = false;
          _currentPath = null;
          _pendingProfile = null;
          _validationError = result.errorMessage ?? 'Sample could not be verified. Please speak clearly at normal volume.';
        });
        return;
      }

      setState(() {
        _hasReview = true;
        _pendingProfile = result.profile;
        _validationError = null;
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _hasReview = false;
        _validationError = 'Failed to process audio: ${e.toString()}';
      });
    }
  }

  Future<void> _playback() async {
    if (_currentPath == null) return;
    try {
      if (_isPlaying) {
        await _player.stop();
        setState(() => _isPlaying = false);
        return;
      }
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(DeviceFileSource(_currentPath!));
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError =
              'Could not play back the recording: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _discardCurrent() async {
    if (_currentPath != null) {
      final f = File(_currentPath!);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _hasReview = false;
      _currentPath = null;
      _pendingProfile = null;
      _validationError = null;
    });
  }

  Future<void> _acceptRecording() async {
    if (_pendingProfile == null) return;

    // Clean up temporary audio file
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (await file.exists()) await file.delete();
    }

    setState(() {
      _captured.add(_pendingProfile!);
      _hasReview = false;
      _currentPath = null;
      _pendingProfile = null;
      _validationError = null;
    });

    if (_captured.length >= totalRecordings) {
      await _finishEnrollment();
    }
  }

  Future<void> _finishEnrollment() async {
    setState(() => _isSaving = true);
    try {
      final averaged = VoiceProfile.average(_captured);
      await _enrollmentService.savePhraseEnrollment(
        phraseId: widget.phraseId,
        phrase: widget.phrase,
        profile: averaged,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Voice profile successfully enrolled and active!'),
            backgroundColor: AppColors.success,
          ),
        );

        if (widget.isOnboarding) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 0)),
            (route) => false,
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError =
              'Could not save voice profile: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _failAndGoToProfile(String reason) async {
    // Preserve the emergency phrase already created, but mark voice enrollment as incomplete
    try {
      await _enrollmentService.saveIncompletePhrase(
        phraseId: widget.phraseId,
        phrase: widget.phrase,
        completeOnboarding: true,
      );
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Voice setup incomplete: $reason. You can complete it in Profile.',
        ),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ),
    );

    if (widget.isOnboarding) {
      // Direct user to Profile screen inside MainShell so they can retry without being locked out
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 4)),
        (route) => false,
      );
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampleNum = (_captured.length + 1).clamp(1, totalRecordings);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Enrollment'),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Voice sample $sampleNum of $totalRecordings',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Say your emergency phrase once clearly at normal volume. SafeHer builds your voice profile to verify emergency activations.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalRecordings,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _captured.length
                          ? AppColors.success
                          : AppColors.border,
                      border: Border.all(
                        color: i == _captured.length
                            ? AppColors.primaryLight
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Emergency Phrase to Speak:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '"${widget.phrase}"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Icon(
                      _isRecording
                          ? Icons.graphic_eq
                          : (_hasReview
                                ? Icons.check_circle_outline
                                : Icons.mic_none_outlined),
                      size: 64,
                      color: _isRecording
                          ? AppColors.dangerLight
                          : (_hasReview
                                ? AppColors.success
                                : AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_isRecording)
                      const Text(
                        'Listening… speak the phrase once',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerLight,
                        ),
                      ),
                    if (_hasReview)
                      const Text(
                        'Sample analyzed successfully!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!_isRecording && !_hasReview)
                      ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.mic),
                        label: Text('Record Sample $sampleNum'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    if (_isRecording)
                      ElevatedButton.icon(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Done Speaking (Stop)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    if (_hasReview) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _playback,
                            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
                            label: Text(_isPlaying ? 'Stop' : 'Listen'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: _discardCurrent,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Re-record'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _acceptRecording,
                        icon: const Icon(Icons.check),
                        label: Text(
                          sampleNum == totalRecordings
                              ? 'Save Voice Profile'
                              : 'Accept & Continue to Sample ${sampleNum + 1}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.dangerLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.dangerLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                TextButton(
                  onPressed: () => _failAndGoToProfile('Setup skipped by user'),
                  child: Text(
                    widget.isOnboarding
                        ? 'Finish voice setup later in Profile'
                        : 'Cancel',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
