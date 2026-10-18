import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/safety_plan.dart';
import 'auth_helpers.dart';

class SafetyPlanService {
  final _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docFor(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('safetyPlan')
      .doc('main');

  DocumentReference<Map<String, dynamic>> _savedTipsDoc(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('safetyPlan')
          .doc('savedTips');

  Stream<SafetyPlan> watchPlan() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(SafetyPlan.empty());
      return _docFor(user.uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return SafetyPlan.empty();
        return SafetyPlan.fromMap(doc.data()!);
      });
    });
  }

  /// Returns true if the server confirmed the save. Offline, Firestore keeps
  /// the write on the phone and uploads it later, so this gives up waiting
  /// after a few seconds and returns false instead of hanging.
  Future<bool> savePlan(SafetyPlan plan) async {
    final uid = await requireUid();
    var confirmed = true;
    await _docFor(uid)
        .set(plan.toMap())
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            confirmed = false;
          },
        );
    return confirmed;
  }

  /// The ids of the safety tips the user starred.
  Stream<Set<String>> watchSavedTips() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<String>{});
      return _savedTipsDoc(user.uid).snapshots().map((doc) {
        final ids = doc.data()?['ids'];
        if (ids is List) return ids.map((e) => e.toString()).toSet();
        return <String>{};
      });
    });
  }

  Future<void> setSavedTips(Set<String> ids) async {
    final uid = await requireUid();
    await _savedTipsDoc(uid).set({'ids': ids.toList()});
  }
}
