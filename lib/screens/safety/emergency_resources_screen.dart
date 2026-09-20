import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class _Resource {
  final String name;
  final String description;
  final String? callNumber;
  const _Resource({
    required this.name,
    required this.description,
    this.callNumber,
  });
}

const _resources = [
  _Resource(
    name: 'National Emergency Number',
    description: 'Unified number for Police, Fire, and Ambulance — works nationwide, even without a SIM.',
    callNumber: '112',
  ),
  _Resource(
    name: 'Police',
    description: 'Direct police control room line.',
    callNumber: '100',
  ),
  _Resource(
    name: 'Ambulance',
    description: 'Free ambulance service, available in most states.',
    callNumber: '108',
  ),
  _Resource(
    name: 'Women Helpline',
    description: '24/7 support for women facing violence or harassment — Ministry of Women & Child Development.',
    callNumber: '181',
  ),
  _Resource(
    name: "Women Helpline (Police)",
    description: "Alternate women's helpline connecting directly to police women's cells.",
    callNumber: '1091',
  ),
];

class EmergencyResourcesScreen extends StatelessWidget {
  const EmergencyResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Resources')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Verified national Indian emergency resources.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._resources.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (r.callNumber != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              launchUrl(Uri.parse('tel:${r.callNumber}')),
                          icon: const Icon(Icons.call, size: 16),
                          label: Text('Call ${r.callNumber}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
