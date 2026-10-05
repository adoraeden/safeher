import 'package:flutter/material.dart';

import '../../services/voice_enrollment_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'voice_sos_guidelines_screen.dart';

class CreateEmergencyPhraseScreen extends StatefulWidget {
  const CreateEmergencyPhraseScreen({super.key});

  @override
  State<CreateEmergencyPhraseScreen> createState() =>
      _CreateEmergencyPhraseScreenState();
}

class _CreateEmergencyPhraseScreenState
    extends State<CreateEmergencyPhraseScreen> {
  final _phraseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _voiceEnrollmentService = VoiceEnrollmentService();
  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _examplePhrases = [
    'SafeHer help me',
    'I need help',
    'Call for help',
  ];

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  String? _validatePhrase(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an emergency phrase.';
    }
    final trimmed = value.trim();

    // Check that it contains actual alphabetic words
    final hasWords = RegExp(r'[a-zA-Z]{2,}').hasMatch(trimmed);
    if (!hasWords) {
      return 'Phrase must contain actual recognizable words.';
    }

    // Reasonably short
    if (trimmed.length > 45) {
      return 'Phrase is too long. Keep it under 45 characters.';
    }

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length > 8) {
      return 'Phrase should be short (up to 8 words) so you can say it quickly in an emergency.';
    }

    return null;
  }

  Future<void> _submitPhrase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final phraseText = _phraseController.text.trim();

    try {
      // Persist the emergency phrase to the authenticated user's account
      final phraseObj = await _voiceEnrollmentService.saveIncompletePhrase(
        phrase: phraseText,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceSosGuidelinesScreen(
              phrase: phraseObj.phrase,
              phraseId: phraseObj.id,
              isOnboarding: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not save phrase: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Setup Voice SOS'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.record_voice_over,
                        size: 32,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Create Your Emergency Phrase',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Voice-triggered SOS is a core safety feature of SafeHer. During an emergency, speaking your chosen phrase hands-free will immediately activate the SOS workflow. This setup cannot be skipped.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.dangerLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _phraseController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Your Emergency Phrase',
                        hintText: 'e.g. SafeHer help me',
                        prefixIcon: Icon(Icons.emergency_outlined),
                      ),
                      validator: _validatePhrase,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Example phrases (tap to choose):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _examplePhrases.map((example) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          label: Text(
                            '"$example"',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                          onPressed: () {
                            setState(() {
                              _phraseController.text = example;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submitPhrase,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Emergency Phrase & Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
