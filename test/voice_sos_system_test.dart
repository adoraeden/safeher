import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/models/emergency_event.dart';
import 'package:women_safety/models/user_profile.dart';
import 'package:women_safety/models/voice_phrase.dart';
import 'package:women_safety/models/voice_profile.dart';
import 'package:women_safety/services/voice_feature_extractor.dart';
import 'package:women_safety/services/voice_guard_service.dart';

void main() {
  group('VoicePhrase Model', () {
    test('serializes and deserializes accurately with profile', () {
      final profile = VoiceProfile(
        avgPitchHz: 180.5,
        pitchVariance: 24.0,
        avgEnergy: 0.05,
        durationSeconds: 1.8,
      );

      final phrase = VoicePhrase(
        id: 'phrase_1',
        phrase: 'SafeHer help me',
        profile: profile,
        isEnrolled: true,
        createdAt: DateTime(2026, 9, 24, 10, 0, 0),
      );

      final map = phrase.toMap();
      final rebuilt = VoicePhrase.fromMap(map);

      expect(rebuilt.id, 'phrase_1');
      expect(rebuilt.phrase, 'SafeHer help me');
      expect(rebuilt.isEnrolled, isTrue);
      expect(rebuilt.profile, isNotNull);
      expect(rebuilt.profile!.avgPitchHz, closeTo(180.5, 0.01));
    });

    test('handles null profile for unenrolled phrase', () {
      final phrase = VoicePhrase(
        id: 'phrase_2',
        phrase: 'I need help',
        profile: null,
        isEnrolled: false,
        createdAt: DateTime.now(),
      );

      final map = phrase.toMap();
      final rebuilt = VoicePhrase.fromMap(map);

      expect(rebuilt.isEnrolled, isFalse);
      expect(rebuilt.profile, isNull);
    });
  });

  group('UserProfile - Multiple Phrases & Legacy Migration', () {
    test('synthesizes VoicePhrase list from legacy voiceTriggerPhrases', () {
      final map = {
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'voiceTriggerPhrases': ['SafeHer help me', 'Call police'],
        'voiceEnrollmentComplete': true,
        'voiceProfile': {
          'avgPitchHz': 210.0,
          'pitchVariance': 15.0,
          'avgEnergy': 0.08,
          'durationSeconds': 2.0,
        },
      };

      final profile = UserProfile.fromMap(map);
      expect(profile.enrolledPhrases.length, 2);
      expect(profile.enrolledPhrases[0].phrase, 'SafeHer help me');
      expect(profile.enrolledPhrases[0].isEnrolled, isTrue);
      expect(profile.enrolledPhrases[0].profile, isNotNull);
      expect(profile.enrolledPhrases[1].phrase, 'Call police');
      expect(profile.enrolledPhrases[1].isEnrolled, isFalse);
      expect(profile.voiceEnrollmentComplete, isTrue);
      expect(profile.voiceTriggerPhrase, 'SafeHer help me');
    });

    test('marks voiceEnrollmentComplete as false when no phrases are enrolled', () {
      final map = {
        'name': 'Alice',
        'email': 'alice@example.com',
        'enrolledPhrases': [
          {
            'id': 'p1',
            'phrase': 'Help me',
            'isEnrolled': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      };

      final profile = UserProfile.fromMap(map);
      expect(profile.voiceEnrollmentComplete, isFalse);
      expect(profile.voiceTriggerPhrases, ['Help me']);
    });
  });

  group('VoiceTriggerMatcher - findMatch with Multiple Phrases', () {
    final phrases = ['SafeHer help me', 'I need help', 'Call for help'];

    test('identifies matching phrase precisely', () {
      expect(
        VoiceTriggerMatcher.findMatch('SafeHer help me please', phrases),
        'SafeHer help me',
      );
      expect(
        VoiceTriggerMatcher.findMatch('somebody I need help right now', phrases),
        'I need help',
      );
      expect(
        VoiceTriggerMatcher.findMatch('please call for help', phrases),
        'Call for help',
      );
    });

    test('returns null when heard text does not match any phrase', () {
      expect(
        VoiceTriggerMatcher.findMatch('what is the weather today', phrases),
        isNull,
      );
      expect(
        VoiceTriggerMatcher.findMatch('safe from danger', phrases),
        isNull,
      );
    });
  });

  group('VoiceFeatureExtractor - Validation & Rejection', () {
    test('rejects empty or truncated wav bytes', () {
      final result = VoiceFeatureExtractor.validateAndExtractFromWav(
        Uint8List(20),
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('corrupted'));
    });

    test('rejects silent / low-energy audio recordings', () {
      // 44-byte standard WAV header + 1 second of silence (zeros) at 16kHz 16-bit PCM
      final wav = Uint8List(44 + 32000);
      final result = VoiceFeatureExtractor.validateAndExtractFromWav(wav);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('quiet'));
    });
  });

  group('EmergencyEvent - Source and Phrase Attribution', () {
    test('preserves source and triggerPhrase in event serialization', () {
      final event = EmergencyEvent(
        id: 'ev_123',
        lat: 37.7749,
        lng: -122.4194,
        timestamp: DateTime(2026, 9, 24, 10, 0, 0),
        status: 'ACTIVE',
        source: 'voice',
        triggerPhrase: 'SafeHer help me',
        notifiedContacts: [],
      );

      final map = event.toMap();
      expect(map['source'], 'voice');
      expect(map['triggerPhrase'], 'SafeHer help me');

      final rebuilt = EmergencyEvent.fromMap('ev_123', map);
      expect(rebuilt.source, 'voice');
      expect(rebuilt.triggerPhrase, 'SafeHer help me');
    });

    test('defaults source to manual when omitted', () {
      final rebuilt = EmergencyEvent.fromMap('ev_456', {
        'lat': 10.0,
        'lng': 20.0,
        'status': 'ACTIVE',
      });
      expect(rebuilt.source, 'manual');
      expect(rebuilt.triggerPhrase, isNull);
    });
  });
}
