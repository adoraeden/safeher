import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<UserProfile?> watchProfile() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore.collection('users').doc(user.uid).snapshots().map((
        doc,
      ) {
        if (!doc.exists) return null;
        return UserProfile.fromMap(doc.data()!);
      });
    });
  }

  Future<void> updateTriggerPhrases(List<String> phrases) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _firestore.collection('users').doc(uid).update({
      'voiceTriggerPhrases': phrases,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
  }
}
