import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_contact.dart';
import 'auth_helpers.dart';

class ContactsService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsRefFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('contacts');
  }

  Stream<List<EmergencyContact>> watchContacts() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<EmergencyContact>[]);
      return _contactsRefFor(user.uid).snapshots().map((snapshot) {
        final contacts = snapshot.docs
            .map((doc) => EmergencyContact.fromMap(doc.id, doc.data()))
            .toList();
        contacts.sort((a, b) => a.priority == 'primary' ? -1 : 1);
        return contacts;
      });
    });
  }

  /// Used by SOS. It reads the copy saved on the phone first, which is
  /// instant even with a weak or missing connection. Only if the phone has
  /// no copy does it ask the server, and it will not wait longer than 8 seconds.
  Future<List<EmergencyContact>> getContactsOnce() async {
    final uid = await requireUid();
    final ref = _contactsRefFor(uid);

    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) {
        return cached.docs
            .map((doc) => EmergencyContact.fromMap(doc.id, doc.data()))
            .toList();
      }
    } catch (_) {
      // No saved copy yet. Fall through to the server.
    }

    final snapshot = await ref.get().timeout(const Duration(seconds: 8));
    return snapshot.docs
        .map((doc) => EmergencyContact.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> addContact(EmergencyContact contact) async {
    final uid = await requireUid();
    await _contactsRefFor(uid).add(contact.toMap());
  }

  Future<void> updateContact(String id, EmergencyContact contact) async {
    final uid = await requireUid();
    await _contactsRefFor(uid).doc(id).update(contact.toMap());
  }

  Future<void> deleteContact(String id) async {
    final uid = await requireUid();
    await _contactsRefFor(uid).doc(id).delete();
  }
}
