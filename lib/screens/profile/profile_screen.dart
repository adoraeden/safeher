import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../models/voice_phrase.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/phrase_quality_hint.dart';
import '../onboarding/voice_enrollment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();

  Future<void> _openEnrollment(VoicePhrase phrase) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceEnrollmentScreen(
          phrase: phrase.phrase,
          phraseId: phrase.id,
          isOnboarding: false,
        ),
      ),
    );
  }

  void _showAddPhraseDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Add Emergency Phrase'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter a phrase to trigger hands-free SOS. You will record this phrase 3 times to create its voice profile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Phrase',
                      hintText: 'e.g. Call for help',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter a phrase';
                      }
                      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(val.trim())) {
                        return 'Phrase must contain actual words';
                      }
                      if (val.trim().length > 45) {
                        return 'Phrase is too long (max 45 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PhraseQualityHint(controller: controller),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    children:
                        ['SafeHer help me', 'I need help', 'Call for help']
                            .map(
                              (sample) => ActionChip(
                                label: Text(
                                  sample,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: AppColors.surfaceElevated,
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = sample;
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final text = controller.text.trim();
                  Navigator.pop(dialogCtx);

                  try {
                    final newPhrase = await _profileService.addEmergencyPhrase(
                      text,
                    );
                    if (mounted) {
                      await _openEnrollment(newPhrase);
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error adding phrase: ${e.toString().replaceFirst('Exception: ', '')}',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add & Record Voice'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePhraseDialog(VoicePhrase existingPhrase) {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: existingPhrase.phrase);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change Emergency Phrase'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Changing this phrase will reset its voice profile. Old voice recordings will NOT be reused for the new phrase. You will record the new phrase 3 times.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'New Phrase',
                    hintText: 'e.g. SafeHer help me',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter a phrase';
                    }
                    if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(val.trim())) {
                      return 'Phrase must contain actual words';
                    }
                    if (val.trim().length > 45) {
                      return 'Phrase is too long (max 45 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                PhraseQualityHint(controller: controller),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newText = controller.text.trim();
              Navigator.pop(dialogCtx);

              try {
                final updated = await _profileService.updatePhraseText(
                  existingPhrase.id,
                  newText,
                );
                if (mounted) {
                  await _openEnrollment(updated);
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error changing phrase: ${e.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Save & Record New Voice'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePhrase(VoicePhrase phrase) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete emergency phrase?'),
        content: Text(
          'Are you sure you want to delete "${phrase.phrase}"? Its associated voice profile will also be deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _profileService.deletePhrase(phrase.id);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Deleted phrase "${phrase.phrase}"'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not delete: ${e.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerLight),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _profileService.signOut();
            },
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.dangerLight),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile and sign-in. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _profileService.deleteAccount();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not delete — try signing out and back in, then retry.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerLight),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.watchProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final phrases = profile?.enrolledPhrases ?? [];
          final bool isVoiceActive = profile?.voiceEnrollmentComplete == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        (profile?.name.isNotEmpty ?? false)
                            ? profile!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? '…',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            profile?.email ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Overall Voice SOS Status Banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isVoiceActive
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isVoiceActive
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isVoiceActive
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: isVoiceActive
                            ? AppColors.success
                            : AppColors.warning,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVoiceActive
                                  ? 'Voice SOS: Voice profile active'
                                  : 'Voice SOS: Voice profile setup incomplete',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isVoiceActive
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isVoiceActive
                                  ? 'Emergency phrases are enrolled with active voice profiles.'
                                  : 'Record your emergency phrase samples to activate hands-free Voice SOS.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Emergency Phrases & Voice Profile Management Card
                _SectionCard(
                  title: 'Emergency Phrases & Voice Profiles',
                  icon: Icons.record_voice_over_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice Guard listens for any of these emergency phrases. Each phrase has its own voice profile to verify your voice.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (phrases.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No emergency phrases configured yet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ] else ...[
                        ...phrases.map((p) => _buildPhraseCard(p)),
                      ],

                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _showAddPhraseDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Another Emergency Phrase'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Privacy & Location
                _SectionCard(
                  title: 'Privacy & location',
                  icon: Icons.privacy_tip_outlined,
                  child: const Text(
                    "Location is only accessed when you trigger SOS or open the Safety Map — never tracked in the background. Raw audio recordings are never stored; only acoustic feature profiles are kept.",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                OutlinedButton(
                  onPressed: _confirmSignOut,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _confirmDeleteAccount,
                    child: const Text(
                      'Delete my account & data',
                      style: TextStyle(color: AppColors.dangerLight),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhraseCard(VoicePhrase phrase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: phrase.isEnrolled
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '"${phrase.phrase}"',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: phrase.isEnrolled
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  phrase.isEnrolled ? '✓ Active' : '⚠ Incomplete',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: phrase.isEnrolled
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!phrase.isEnrolled)
                ElevatedButton.icon(
                  onPressed: () => _openEnrollment(phrase),
                  icon: const Icon(Icons.mic, size: 16),
                  label: const Text('Complete voice setup'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _openEnrollment(phrase),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-record voice profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _showChangePhraseDialog(phrase),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change phrase'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                onPressed: () => _confirmDeletePhrase(phrase),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.dangerLight,
                tooltip: 'Delete phrase',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
