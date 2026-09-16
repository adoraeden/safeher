import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String phaseNote;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.phaseNote,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                phaseNote,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
