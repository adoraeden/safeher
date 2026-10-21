import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class CallEmergencyButton extends StatelessWidget {
  const CallEmergencyButton({super.key});

  Future<void> _dialEmergency(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '112');
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the dialer. Please dial 112 manually.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the dialer. Please dial 112 manually.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _dialEmergency(context),
      icon: const Icon(Icons.phone, color: Colors.white),
      label: const Text(
        'Emergency Call — 112',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
