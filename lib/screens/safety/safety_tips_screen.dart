import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class _TipCategory {
  final String title;
  final IconData icon;
  final List<String> tips;
  const _TipCategory({
    required this.title,
    required this.icon,
    required this.tips,
  });
}

const _categories = [
  _TipCategory(
    title: 'Travel safety',
    icon: Icons.directions_walk,
    tips: [
      'Share your live trip with a trusted contact before you set off.',
      'Keep your phone charged and easily reachable, not buried in a bag.',
      'Sit near the driver or other passengers on public transport when possible.',
      'Trust your instincts — if a ride or situation feels wrong, exit at the next safe opportunity.',
    ],
  ),
  _TipCategory(
    title: 'Night-time safety',
    icon: Icons.nightlight_outlined,
    tips: [
      'Stick to well-lit, busier routes even if they take slightly longer.',
      'Avoid wearing both headphones so you can stay aware of your surroundings.',
      'Have your keys or door entry ready before you reach your door.',
      'Let someone know your expected arrival time.',
    ],
  ),
  _TipCategory(
    title: 'Online safety',
    icon: Icons.shield_outlined,
    tips: [
      'Avoid sharing your real-time location publicly on social media.',
      'Be cautious meeting someone from online for the first time — choose a public place and tell someone where you\'ll be.',
      'Use strong, unique passwords and enable two-factor authentication where available.',
      'Trust your judgment if a message or contact feels manipulative or pressuring.',
    ],
  ),
  _TipCategory(
    title: 'Public-place safety',
    icon: Icons.storefront_outlined,
    tips: [
      'Keep valuables secure and out of sight in crowded places.',
      'Identify exits and staff/security locations when you arrive somewhere new.',
      'Stay near groups or staffed areas if you feel uneasy.',
      'It\'s okay to ask venue staff for help or an escort to your transport.',
    ],
  ),
  _TipCategory(
    title: 'Emergency preparedness',
    icon: Icons.backpack_outlined,
    tips: [
      'Keep 2-3 emergency contacts up to date in the app at all times.',
      'Know your exact address or nearest cross-streets in case you need to share it quickly.',
      'Familiarize yourself with the SOS and Voice Guard features before you need them.',
      'Review your Safety Plan periodically, especially before travel.',
    ],
  ),
];

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Tips')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.border),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.border),
              ),
              backgroundColor: AppColors.surface,
              collapsedBackgroundColor: AppColors.surface,
              leading: Icon(category.icon, color: AppColors.primaryLight),
              title: Text(
                category.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              children: category.tips
                  .map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}
