import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/voice_phrase.dart';
import '../models/voice_profile.dart';
import 'auth_helpers.dart';

/// Manages the user's emergency voice phrase(s) and their enrolled voice
/// profiles.
///
/// Storage model: phrases live as an array field `enrolledPhrases` embedded
/// directly on the users/{uid} document (matching UserProfile.fromMap /
/// toMap), NOT as a separate subcollection. `voiceTriggerPhrases` (a plain
/// list of phrase strings) is kept in sync alongside it for legacy readers.
class VoiceEnrollmentService {
  final _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Future<List<VoicePhrase>> _readPhrases(String uid) async {
    final doc = await _userDoc(uid).get();
    final data = doc.data();
    if (data == null || data['enrolledPhrases'] is! List) return [];
    return (data['enrolledPhrases'] as List)
        .map((item) => VoicePhrase.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _writePhrases(String uid, List<VoicePhrase> phrases) async {
    final anyEnrolled = phrases.any((p) => p.isEnrolled);
    await _userDoc(uid).set({
      'enrolledPhrases': phrases.map((p) => p.toMap()).toList(),
      'voiceTriggerPhrases': phrases.map((p) => p.phrase).toList(),
      // Kept in sync for any legacy code paths that still read these
      // top-level flags directly.
      'voiceEnrollmentComplete': anyEnrolled,
      if (anyEnrolled) 'onboardingCompleted': true,
    }, SetOptions(merge: true));
  }

  /// Creates or updates a phrase record without marking it enrolled.
  /// Used both for the first phrase created during onboarding and for
  /// adding/leaving-incomplete additional phrases later from Profile.
  ///
  /// If [phraseId] is null, a new phrase is created.
  /// If [completeOnboarding] is true, the user's account is also marked as
  /// having finished the mandatory voice setup step (even though this
  /// particular phrase isn't enrolled yet), so onboarding doesn't force the
  /// user back into this flow — they can finish it later from Profile.
  Future<VoicePhrase> saveIncompletePhrase({
    String? phraseId,
    required String phrase,
    bool completeOnboarding = false,
  }) async {
    final uid = await requireUid();
    final phrases = await _readPhrases(uid);
    final id = phraseId ?? _uuid.v4();
    final idx = phrases.indexWhere((p) => p.id == id);
    final existing = idx >= 0 ? phrases[idx] : null;

    final updated = VoicePhrase(
      id: id,
      phrase: phrase,
      profile: existing?.profile,
      isEnrolled: existing?.isEnrolled ?? false,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    if (idx >= 0) {
      phrases[idx] = updated;
    } else {
      phrases.add(updated);
    }
    await _writePhrases(uid, phrases);

    if (completeOnboarding) {
      await _userDoc(uid)
          .set({'onboardingCompleted': true}, SetOptions(merge: true));
    }

    return updated;
  }

  /// Saves a completed voice enrollment (averaged profile from the captured
  /// samples) for a phrase, marking it as fully enrolled and active.
  Future<void> savePhraseEnrollment({
    String? phraseId,
    required String phrase,
    required VoiceProfile profile,
  }) async {
    final uid = await requireUid();
    final phrases = await _readPhrases(uid);
    final id = phraseId ?? _uuid.v4();
    final idx = phrases.indexWhere((p) => p.id == id);

    final updated = VoicePhrase(
      id: id,
      phrase: phrase,
      profile: profile,
      isEnrolled: true,
      createdAt: idx >= 0 ? phrases[idx].createdAt : DateTime.now(),
    );

    if (idx >= 0) {
      phrases[idx] = updated;
    } else {
      phrases.add(updated);
    }
    await _writePhrases(uid, phrases);
  }

  /// Updates just the spoken phrase text for an existing phrase record.
  /// Does not touch its enrollment status or profile.
  Future<VoicePhrase> updatePhraseText({
    required String phraseId,
    required String newPhrase,
  }) async {
    final uid = await requireUid();
    final phrases = await _readPhrases(uid);
    final idx = phrases.indexWhere((p) => p.id == phraseId);
    if (idx < 0) {
      throw Exception('Phrase not found.');
    }
    final updated = phrases[idx].copyWith(phrase: newPhrase);
    phrases[idx] = updated;
    await _writePhrases(uid, phrases);
    return updated;
  }

  Future<void> deletePhrase(String phraseId) async {
    final uid = await requireUid();
    final phrases = await _readPhrases(uid);
    phrases.removeWhere((p) => p.id == phraseId);
    await _writePhrases(uid, phrases);
  }

  /// Returns all phrases (enrolled or not) for the current user.
  Future<List<VoicePhrase>> getAllPhrases() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    return _readPhrases(uid);
  }

  /// Returns the enrolled voice profile matching a specific detected phrase
  /// (case-insensitive, trimmed), or null if no enrolled phrase matches.
  Future<VoiceProfile?> getProfileForPhrase(String phrase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final normalized = phrase.trim().toLowerCase();
    final phrases = await _readPhrases(uid);
    for (final p in phrases) {
      if (p.isEnrolled &&
          p.profile != null &&
          p.phrase.trim().toLowerCase() == normalized) {
        return p.profile;
      }
    }
    return null;
  }

  /// Fallback used when no specific phrase was detected: returns any one
  /// enrolled voice profile for the current user, if one exists.
  Future<VoiceProfile?> getProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final phrases = await _readPhrases(uid);
    for (final p in phrases) {
      if (p.isEnrolled && p.profile != null) return p.profile;
    }
    return null;
  }
}
