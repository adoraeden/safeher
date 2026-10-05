import 'voice_phrase.dart';
import 'voice_profile.dart';

class UserProfile {
  final String name;
  final String email;
  final List<String> voiceTriggerPhrases;
  final List<VoicePhrase> enrolledPhrases;
  final bool voiceEnrollmentComplete;
  final bool onboardingCompleted;

  UserProfile({
    required this.name,
    required this.email,
    required this.voiceTriggerPhrases,
    this.enrolledPhrases = const [],
    required this.voiceEnrollmentComplete,
    this.onboardingCompleted = false,
  });

  /// Backward-compatible getter expected by existing tests and legacy views.
  String get voiceTriggerPhrase =>
      voiceTriggerPhrases.isNotEmpty ? voiceTriggerPhrases.first : 'SafeHer help me';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    List<VoicePhrase> phrasesList = [];
    if (map['enrolledPhrases'] is List) {
      phrasesList = (map['enrolledPhrases'] as List)
          .map((item) => VoicePhrase.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<String> stringPhrases = [];
    if (phrasesList.isNotEmpty) {
      stringPhrases = phrasesList.map((p) => p.phrase).toList();
    } else if (map['voiceTriggerPhrases'] is List) {
      stringPhrases = List<String>.from(map['voiceTriggerPhrases']);
    } else if (map['voiceTriggerPhrase'] is String &&
        (map['voiceTriggerPhrase'] as String).isNotEmpty) {
      stringPhrases = [map['voiceTriggerPhrase']];
    } else {
      stringPhrases = [];
    }

    // Synthesize enrolledPhrases if absent in legacy records
    if (phrasesList.isEmpty && stringPhrases.isNotEmpty) {
      final legacyProfile = map['voiceProfile'] != null
          ? VoiceProfile.fromMap(Map<String, dynamic>.from(map['voiceProfile']))
          : null;
      final legacyComplete = map['voiceEnrollmentComplete'] == true;

      for (int i = 0; i < stringPhrases.length; i++) {
        final phraseStr = stringPhrases[i];
        phrasesList.add(
          VoicePhrase(
            id: 'legacy_$i',
            phrase: phraseStr,
            profile: i == 0 ? legacyProfile : null,
            isEnrolled: i == 0 && legacyComplete,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    final bool isEnrolled = phrasesList.isNotEmpty
        ? phrasesList.any((p) => p.isEnrolled)
        : (map['voiceEnrollmentComplete'] == true);

    final bool isOnboardingDone = (map['onboardingCompleted'] == true) ||
        (map['voiceEnrollmentComplete'] == true);

    return UserProfile(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      voiceTriggerPhrases: stringPhrases,
      enrolledPhrases: phrasesList,
      voiceEnrollmentComplete: isEnrolled,
      onboardingCompleted: isOnboardingDone,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'voiceTriggerPhrases': voiceTriggerPhrases,
    'enrolledPhrases': enrolledPhrases.map((p) => p.toMap()).toList(),
    'voiceEnrollmentComplete': voiceEnrollmentComplete,
    'onboardingCompleted': onboardingCompleted,
  };
}
