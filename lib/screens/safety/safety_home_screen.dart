import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'safety_tips_screen.dart';
import 'safety_plan_screen.dart';
import 'emergency_resources_screen.dart';

class SafetyHomeScreen extends StatelessWidget {
  const SafetyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SafetyHubTile(
              icon: Icons.checklist_outlined,
              color: AppColors.primaryLight,
              title: 'My Safety Plan',
              subtitle: 'Safe places, notes, and a personal prep checklist',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafetyPlanScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SafetyHubTile(
              icon: Icons.lightbulb_outline,
              color: AppColors.warning,
              title: 'Safety Tips',
              subtitle: 'Practical guidance by situation',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafetyTipsScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SafetyHubTile(
              icon: Icons.phone_in_talk_outlined,
              color: AppColors.success,
              title: 'Emergency Resources',
              subtitle: 'Verified national helplines',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyResourcesScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyHubTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SafetyHubTile({
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
