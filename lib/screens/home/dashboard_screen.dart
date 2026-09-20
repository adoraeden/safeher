import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/emergency_contact.dart';
import '../../models/user_profile.dart';
import '../../services/contacts_service.dart';
import '../../services/emergency_service.dart';
import '../../services/profile_service.dart';
import '../../services/voice_guard_service.dart';
import '../../services/alarm_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_radius.dart';
import '../contacts/emergency_contacts_screen.dart';
import '../sos/sos_active_screen.dart';
import '../sos/voice_trigger_confirm_screen.dart';
import '../incidents/report_incident_screen.dart';
import '../location/live_location_screen.dart';
import '../route/route_check_screen.dart';
import '../../widgets/sos_hold_button.dart';

import 'package:geolocator/geolocator.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex)? onQuickAction;

  const DashboardScreen({super.key, this.onQuickAction});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }

  void _openContacts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
    );
  }

  void _openReportIncident(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
    );
  }

  void _openLiveLocation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveLocationScreen()),
    );
  }

  void _openRouteCheck(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RouteCheckScreen()),
    );
  }

  Future<void> _triggerSos(BuildContext context) async {
    try {
      final event = await EmergencyService().triggerSos();
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SosActiveScreen(event: event)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<EmergencyContact>>(
          stream: ContactsService().watchContacts(),
          builder: (context, contactsSnapshot) {
            final contacts = contactsSnapshot.data ?? [];

            return StreamBuilder<UserProfile?>(
              stream: ProfileService().watchProfile(),
              builder: (context, profileSnapshot) {
                final triggerPhrases =
                    profileSnapshot.data?.voiceTriggerPhrases ??
                    ['SafeHer help me'];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusPill(),
                      const SizedBox(height: AppSpacing.lg),
                      _EmergencyHero(onTrigger: () => _triggerSos(context)),
                      const SizedBox(height: AppSpacing.md),
                      _VoiceGuardCard(triggerPhrases: triggerPhrases),
                      const SizedBox(height: AppSpacing.md),
                      const _AlarmCard(),
                      const SizedBox(height: AppSpacing.md),
                      const _RiskIndicatorCard(),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _SafetyShieldCard(
                              contactCount: contacts.length,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _LocationCard(
                              onRefresh: () => _comingSoon(
                                context,
                                'Live GPS refresh (Phase 4)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'Quick safety actions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.9,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        children: [
                          _QuickActionCard(
                            icon: Icons.share_location_outlined,
                            color: AppColors.warning,
                            title: 'Share location',
                            subtitle: 'Share GPS / journey',
                            onTap: () => _openLiveLocation(context),
                          ),
                          _QuickActionCard(
                            icon: Icons.description_outlined,
                            color: AppColors.dangerLight,
                            title: 'Report hazard',
                            subtitle: 'Alert community',
                            onTap: () => _openReportIncident(context),
                          ),
                          _QuickActionCard(
                            icon: Icons.near_me_outlined,
                            color: AppColors.primaryLight,
                            title: 'Route check',
                            subtitle: 'Safe commute AI',
                            onTap: () => _openRouteCheck(context),
                          ),
                          _QuickActionCard(
                            icon: Icons.chat_bubble_outline,
                            color: AppColors.accent,
                            title: 'AI assistant',
                            subtitle: 'Gemini safety',
                            onTap: () => onQuickAction?.call(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _TrustedContactsCard(
                        contacts: contacts,
                        onManage: () => _openContacts(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _HelplinesCard(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlarmCard extends StatefulWidget {
  const _AlarmCard();

  @override
  State<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<_AlarmCard> {
  final _alarmService = AlarmService();
  bool _isPlaying = false;

  @override
  void dispose() {
    _alarmService.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _alarmService.stop();
    } else {
      await _alarmService.start();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _isPlaying
              ? AppColors.danger.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _isPlaying ? AppColors.danger : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isPlaying ? Icons.volume_up : Icons.campaign_outlined,
              color: _isPlaying
                  ? AppColors.dangerLight
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPlaying ? 'Alarm playing — tap to stop' : 'Loud Alarm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isPlaying
                          ? AppColors.dangerLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Plays a loud siren to draw attention',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskIndicatorCard extends StatefulWidget {
  const _RiskIndicatorCard();

  @override
  State<_RiskIndicatorCard> createState() => _RiskIndicatorCardState();
}

class _RiskIndicatorCardState extends State<_RiskIndicatorCard> {
  bool _isLoading = true;
  RiskAssessment? _assessment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('location off');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('permission needed');
      }
      final position = await Geolocator.getCurrentPosition();
      final assessment = await RiskAssessmentService().assessCurrentRisk(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) {
        setState(() {
          _assessment = assessment;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'unavailable';
          _isLoading = false;
        });
      }
    }
  }

  Color _colorFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return AppColors.dangerLight;
    }
  }

  String _labelFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'Elevated';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: _isLoading
          ? const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Checking local safety signal…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : _error != null
          ? const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Risk indicator unavailable — check location permission',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _colorFor(_assessment!.level),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local safety signal: ${_labelFor(_assessment!.level)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Based on time of day and ${_assessment!.nearbyReportCount} nearby report${_assessment!.nearbyReportCount == 1 ? '' : 's'} this month — not a guarantee.',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _VoiceGuardCard extends StatefulWidget {
  final List<String> triggerPhrases;
  const _VoiceGuardCard({required this.triggerPhrases});

  @override
  State<_VoiceGuardCard> createState() => _VoiceGuardCardState();
}

class _VoiceGuardCardState extends State<_VoiceGuardCard> {
  final _voiceGuard = VoiceGuardService();
  bool _isOn = false;
  bool _isStarting = false;

  @override
  void dispose() {
    _voiceGuard.stop();
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      setState(() => _isStarting = true);
      final started = await _voiceGuard.start(
        triggerPhrases: widget.triggerPhrases,
        onTriggerDetected: () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoiceTriggerConfirmScreen(),
              ),
            );
          }
        },
      );
      if (mounted) {
        setState(() {
          _isOn = started;
          _isStarting = false;
        });
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Add a trigger phrase in Profile, and allow microphone access.',
              ),
            ),
          );
        }
      }
    } else {
      _voiceGuard.stop();
      setState(() => _isOn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _isOn ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _isOn ? Icons.mic : Icons.mic_none_outlined,
            color: _isOn ? AppColors.primaryLight : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Guard',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _isOn
                      ? 'Listening for ${widget.triggerPhrases.length} phrase${widget.triggerPhrases.length == 1 ? '' : 's'}'
                      : 'Off — say a saved phrase to trigger SOS hands-free',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _isStarting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isOn,
                  onChanged: _toggle,
                  activeColor: AppColors.primary,
                ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Safety shield active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHero extends StatelessWidget {
  final Future<void> Function() onTrigger;
  const _EmergencyHero({required this.onTrigger});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'EMERGENCY DISPATCH SYSTEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.dangerLight,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Instant emergency assistance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'In danger or feeling threatened? Hold the button below for 3 seconds, or use Voice Guard hands-free.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: SosHoldButton(onTriggered: onTrigger)),
        ],
      ),
    );
  }
}

class _SafetyShieldCard extends StatelessWidget {
  final int contactCount;
  const _SafetyShieldCard({required this.contactCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAFETY SHIELD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Protected',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Standard protection',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Text(
            'SafeHer community mode',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),
          Text(
            'Contacts configured: $contactCount trusted',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _LocationCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOCATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(
                  Icons.refresh,
                  size: 14,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Enabled on SOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fetched fresh each time SOS triggers',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustedContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final VoidCallback onManage;

  const _TrustedContactsCard({required this.contacts, required this.onManage});

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Trusted emergency contacts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onManage,
                child: Text('Manage (${contacts.length})'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (contacts.isEmpty)
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 36,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'No emergency contacts configured yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: onManage,
                    child: const Text('Add emergency contacts'),
                  ),
                ],
              ),
            )
          else
            ...contacts
                .take(3)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          c.relationship,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _HelplinesCard extends StatelessWidget {
  const _HelplinesCard();

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
          const Row(
            children: [
              Icon(
                Icons.phone_in_talk_outlined,
                size: 18,
                color: AppColors.primaryLight,
              ),
              SizedBox(width: 8),
              Text(
                'Emergency helplines',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HelplineRow(
            label: 'Emergency (Police/Fire/Ambulance)',
            number: '112',
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.sm),
          _HelplineRow(
            label: 'Women Helpline',
            number: '181',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _HelplineRow(
            label: 'Ambulance',
            number: '108',
            color: AppColors.surfaceElevated,
            textColor: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  final String label;
  final String number;
  final Color color;
  final Color textColor;

  const _HelplineRow({
    required this.label,
    required this.number,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse('tel:$number')),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Row(
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.call, size: 12, color: textColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
