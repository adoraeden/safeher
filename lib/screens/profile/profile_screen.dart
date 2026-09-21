import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _newPhraseController = TextEditingController();
  List<String> _phrases = [];
  bool _initialized = false;
  bool _isSavingPhrases = false;

  @override
  void dispose() {
    _newPhraseController.dispose();
    super.dispose();
  }

  void _addPhrase() {
    final text = _newPhraseController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _phrases = [..._phrases, text];
      _newPhraseController.clear();
    });
  }

  void _removePhrase(int index) {
    setState(() => _phrases = List.of(_phrases)..removeAt(index));
  }

  Future<void> _savePhrases() async {
    setState(() => _isSavingPhrases = true);
    try {
      await _profileService.updateTriggerPhrases(_phrases);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trigger phrases saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPhrases = false);
    }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile and sign-in. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
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
          if (profile != null && !_initialized) {
            _phrases = List.from(profile.voiceTriggerPhrases);
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                _SectionCard(
                  title: 'Voice Guard trigger phrases',
                  icon: Icons.record_voice_over_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Say any of these while Voice Guard is active to start the SOS countdown hands-free. Add as many as you like.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._phrases.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.mic_none_outlined,
                                size: 16,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _removePhrase(entry.key),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newPhraseController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. SafeHer help me',
                              ),
                              onSubmitted: (_) => _addPhrase(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppColors.primary,
                            ),
                            onPressed: _addPhrase,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSavingPhrases ? null : _savePhrases,
                          child: _isSavingPhrases
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Privacy & location',
                  icon: Icons.privacy_tip_outlined,
                  child: const Text(
                    "Location is only accessed when you trigger SOS or open the Safety Map — never tracked in the background.",
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
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _confirmDeleteAccount,
                  child: const Text(
                    'Delete my account & data',
                    style: TextStyle(color: AppColors.dangerLight),
                  ),
                ),
              ],
            ),
          );
        },
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
