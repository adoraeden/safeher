import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum _HintLevel { tip, good, note, warning }

class _PhraseCheck {
  final _HintLevel level;
  final String title;
  final String message;
  const _PhraseCheck(this.level, this.title, this.message);
}

/// Shows advice about the emergency phrase while the user types it.
/// It only advises and never blocks saving.
class PhraseQualityHint extends StatelessWidget {
  final TextEditingController controller;
  const PhraseQualityHint({super.key, required this.controller});

  // Tiny joining words are easy for the voice model to miss.
  static const _joiningWords = {
    'the',
    'is',
    'a',
    'an',
    'of',
    'to',
    'and',
    'it',
    'in',
    'on',
    'at',
    'am',
    'are',
  };

  static _PhraseCheck _check(String text) {
    final words = RegExp(r"[A-Za-z']+")
        .allMatches(text)
        .map((m) => m.group(0)!.toLowerCase())
        .toList();

    if (words.isEmpty) {
      return const _PhraseCheck(
        _HintLevel.tip,
        'Tip: choose 2 or 3 clear, common words',
        'For example "save me now" or "help me please". Everyday words are '
            'recognized best. Names and made-up words often are not.',
      );
    }
    if (words.length == 1) {
      return const _PhraseCheck(
        _HintLevel.warning,
        'A single word is easy to mishear',
        'It can sound like other words and may trigger by mistake, or be '
            'missed when you really need it. Try 2 or 3 words.',
      );
    }
    if (words.length > 4) {
      return const _PhraseCheck(
        _HintLevel.note,
        'Shorter is more reliable',
        'Phrases of 2 to 4 words are detected best, and are quicker to say '
            'in an emergency.',
      );
    }
    final joiners = words.where(_joiningWords.contains).toSet();
    if (joiners.isNotEmpty) {
      return _PhraseCheck(
        _HintLevel.note,
        'Small words can be missed',
        'Words like "${joiners.first}" are short and easy for the voice model '
            'to skip. Try a phrase without them.',
      );
    }
    return const _PhraseCheck(
      _HintLevel.good,
      'Good choice',
      '2 to 4 clear words is the easiest kind of phrase to detect.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final check = _check(value.text);

        final Color color;
        final IconData icon;
        switch (check.level) {
          case _HintLevel.good:
            color = AppColors.success;
            icon = Icons.check_circle_outline;
            break;
          case _HintLevel.warning:
            color = AppColors.warning;
            icon = Icons.warning_amber_rounded;
            break;
          case _HintLevel.note:
            color = AppColors.warning;
            icon = Icons.info_outline;
            break;
          case _HintLevel.tip:
            color = AppColors.primaryLight;
            icon = Icons.lightbulb_outline;
            break;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      check.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
