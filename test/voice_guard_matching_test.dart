import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/services/voice_guard_service.dart';

void main() {
  group('VoiceTriggerMatcher - Normalization', () {
    test('normalizes case, whitespace, and punctuation', () {
      expect(VoiceTriggerMatcher.normalize('  Help ME!  '), 'help me');
      expect(VoiceTriggerMatcher.normalize('SafeHer, help me...'), 'safeher help me');
      expect(VoiceTriggerMatcher.normalize('help - me'), 'help me');
      expect(VoiceTriggerMatcher.normalize('“Help Me!”'), 'help me');
    });

    test('generates compound word variants for safeher', () {
      final variants = VoiceTriggerMatcher.generateVariants('SafeHer help me');
      expect(variants, contains('safeher help me'));
      expect(variants, contains('safe her help me'));
      expect(variants, contains('save her help me'));
    });
  });

  group('VoiceTriggerMatcher - Single-Utterance Detection ("Help me")', () {
    final phrases = ['help me'];

    test('matches single exact utterance', () {
      expect(VoiceTriggerMatcher.matches('help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('Help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('HELP ME', phrases), isTrue);
    });

    test('matches single utterance with trailing punctuation', () {
      expect(VoiceTriggerMatcher.matches('help me.', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('help me!', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('help, me...', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('help me?!', phrases), isTrue);
    });

    test('matches when embedded in a short natural sentence', () {
      expect(VoiceTriggerMatcher.matches('please help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('someone help me right now', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('help me please', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('oh god help me', phrases), isTrue);
    });

    test('matches with minor acoustic / speech recognition variations', () {
      // "helped me" transcribed instead of "help me"
      expect(VoiceTriggerMatcher.matches('helped me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('helps me', phrases), isTrue);
    });
  });

  group('VoiceTriggerMatcher - Default App Phrase ("SafeHer help me")', () {
    final phrases = ['SafeHer help me'];

    test('matches spoken "safeher help me"', () {
      expect(VoiceTriggerMatcher.matches('safeher help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('SafeHer help me!', phrases), isTrue);
    });

    test('matches when speech engine transcribes as two words ("safe her help me")', () {
      expect(VoiceTriggerMatcher.matches('safe her help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('safe her, help me!', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('please safe her help me', phrases), isTrue);
    });

    test('matches phonetic alternative ("save her help me")', () {
      expect(VoiceTriggerMatcher.matches('save her help me', phrases), isTrue);
    });
  });

  group('VoiceTriggerMatcher - Multiple Configured Phrases', () {
    final phrases = ['help me', 'SafeHer help me', 'emergency'];

    test('matches any of the configured phrases', () {
      expect(VoiceTriggerMatcher.matches('help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('SafeHer help me', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('emergency', phrases), isTrue);
      expect(VoiceTriggerMatcher.matches('this is an emergency', phrases), isTrue);
    });
  });

  group('VoiceTriggerMatcher - False Trigger Protection', () {
    final phrases = ['help me'];

    test('rejects reversed word order', () {
      expect(VoiceTriggerMatcher.matches('me help', phrases), isFalse);
    });

    test('rejects phrases where words are scattered across casual conversation', () {
      expect(
        VoiceTriggerMatcher.matches(
          'can you help that person with me tomorrow morning',
          phrases,
        ),
        isFalse,
      );
      expect(
        VoiceTriggerMatcher.matches(
          'she came to me to ask for some help with homework',
          phrases,
        ),
        isFalse,
      );
    });

    test('rejects completely unrelated speech and background noise transcripts', () {
      expect(VoiceTriggerMatcher.matches('what time is the meeting', phrases), isFalse);
      expect(VoiceTriggerMatcher.matches('turn on the television', phrases), isFalse);
      expect(VoiceTriggerMatcher.matches('good morning how are you', phrases), isFalse);
      expect(VoiceTriggerMatcher.matches('playing some music right now', phrases), isFalse);
    });

    test('rejects single-word trigger inside long casual conversation', () {
      final singleWord = ['help'];
      // In short phrase, it matches
      expect(VoiceTriggerMatcher.matches('help', singleWord), isTrue);
      expect(VoiceTriggerMatcher.matches('please help', singleWord), isTrue);
      expect(VoiceTriggerMatcher.matches('help me', singleWord), isTrue);

      // In long casual conversation sentence, single word does not trigger
      expect(
        VoiceTriggerMatcher.matches(
          'can someone please help carry these heavy groceries inside the kitchen',
          singleWord,
        ),
        isFalse,
      );
    });
  });
}
