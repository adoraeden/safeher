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

  Stream<SafetyPlan> watchPlan() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(SafetyPlan.empty());
      return _docFor(user.uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return SafetyPlan.empty();
        return SafetyPlan.fromMap(doc.data()!);
      });
    });
  }

  Future<void> savePlan(SafetyPlan plan) async {
    final uid = await requireUid();
    await _docFor(uid).set(plan.toMap());
  }
}
