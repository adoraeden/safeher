import 'package:flutter/material.dart';

import 'create_emergency_phrase_screen.dart';

/// Legacy alias kept for routing compatibility.
/// The modern flow starts at [CreateEmergencyPhraseScreen].
class MandatoryVoiceSetupScreen extends StatelessWidget {
  const MandatoryVoiceSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateEmergencyPhraseScreen();
  }
}
