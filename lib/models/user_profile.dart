class UserProfile {
  final String name;
  final String email;
  final List<String> voiceTriggerPhrases;

  UserProfile({
    required this.name,
    required this.email,
    required this.voiceTriggerPhrases,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    List<String> phrases;
    if (map['voiceTriggerPhrases'] is List) {
      phrases = List<String>.from(map['voiceTriggerPhrases']);
    } else if (map['voiceTriggerPhrase'] is String &&
        (map['voiceTriggerPhrase'] as String).isNotEmpty) {
      phrases = [map['voiceTriggerPhrase']];
    } else {
      phrases = ['SafeHer help me'];
    }
    return UserProfile(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      voiceTriggerPhrases: phrases,
    );
  }
}
