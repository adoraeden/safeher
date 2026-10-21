import 'package:flutter/material.dart';

import '../../models/emergency_event.dart';
import '../../services/emergency_service.dart';
import '../../services/voice_guard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_radius.dart';
import '../../widgets/call_emergency_button.dart';

class SosActiveScreen extends StatefulWidget {
  final EmergencyEvent event;
  const SosActiveScreen({super.key, required this.event});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {
  bool _isResolving = false;

  Future<void> _markSafe() async {
    setState(() => _isResolving = true);
    try {
      await EmergencyService().resolveSos(widget.event.id);
    } catch (_) {
      // Going back to the app matters more than the status update.
    }
    // Voice Guard pauses itself during an SOS. Start it listening again.
    VoiceGuardService().resume();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _coordText(double lat, double lng) =>
      '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}, '
      '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}';

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(List<Map<String, dynamic>> contacts) {
    if (contacts.isEmpty) {
      return _banner(
        'No contacts were alerted. Add emergency contacts so SOS has someone to reach.',
        AppColors.warning,
        Icons.group_off_outlined,
      );
    }
    if (contacts.every((c) => c['demo'] == true)) {
      return _banner(
        'DEMO MODE: no messages were sent',
        AppColors.warning,
        Icons.science_outlined,
      );
    }
    final sent = contacts.where((c) => c['smsSent'] == true).length;
    if (sent == contacts.length) {
      return _banner(
        'SMS sent to $sent contact${sent == 1 ? '' : 's'}',
        AppColors.success,
        Icons.check_circle_outline,
      );
    }
    if (sent == 0) {
      return _banner(
        'The SMS could not be sent. Check SMS permission and mobile signal, then call your contacts.',
        AppColors.dangerLight,
        Icons.sms_failed_outlined,
      );
    }
    return _banner(
      'SMS sent to $sent of ${contacts.length} contacts. Call the others yourself.',
      AppColors.warning,
      Icons.warning_amber_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final contacts = event.notifiedContacts;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statusBanner(contacts),
                const SizedBox(height: AppSpacing.lg),
                const CallEmergencyButton(),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'SOS ACTIVE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dangerLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Triggered ${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: event.locationFound
                          ? AppColors.border
                          : AppColors.warning.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (event.locationFound)
                        Text(
                          _coordText(event.lat, event.lng),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        )
                      else
                        const Text(
                          'Your location could not be found. Your contacts were told to call you right away. Turn on location and a GPS signal if you can.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warning,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTACTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (contacts.isEmpty)
                        const Text(
                          'No contacts were configured. Add contacts so a real alert has someone to reach.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        ...contacts.map((c) {
                          final isDemo = c['demo'] == true;
                          final sent = c['smsSent'] == true;
                          final Color color = isDemo
                              ? AppColors.textSecondary
                              : (sent
                                    ? AppColors.success
                                    : AppColors.dangerLight);
                          final String label = isDemo
                              ? 'Demo'
                              : (sent ? 'SMS sent' : 'Not sent');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  isDemo
                                      ? Icons.science_outlined
                                      : (sent
                                            ? Icons.check_circle
                                            : Icons.error_outline),
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${c['name']} · ${c['phone']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Emergency services are not called automatically. If you are in danger, call 112.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isResolving ? null : _markSafe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: _isResolving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("I'm safe now"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
