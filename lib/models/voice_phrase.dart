import 'voice_profile.dart';

class VoicePhrase {
  final String id;
  final String phrase;
  final VoiceProfile? profile;
  final bool isEnrolled;
  final DateTime createdAt;

  VoicePhrase({
    required this.id,
    required this.phrase,
    this.profile,
    required this.isEnrolled,
    required this.createdAt,
  });

  VoicePhrase copyWith({
    String? id,
    String? phrase,
    VoiceProfile? profile,
    bool? isEnrolled,
    DateTime? createdAt,
  }) {
    return VoicePhrase(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      profile: profile ?? this.profile,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'phrase': phrase,
    if (profile != null) 'profile': profile!.toMap(),
    'isEnrolled': isEnrolled,
    'createdAt': createdAt.toIso8601String(),
  };

  factory VoicePhrase.fromMap(Map<String, dynamic> map) {
    return VoicePhrase(
      id: map['id']?.toString() ?? '',
      phrase: map['phrase']?.toString() ?? '',
      profile: map['profile'] != null
          ? VoiceProfile.fromMap(Map<String, dynamic>.from(map['profile']))
          : null,
      isEnrolled: map['isEnrolled'] == true,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
