import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_contact.dart';
import 'auth_helpers.dart';

class ContactsService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsRefFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('contacts');
  }

  // Keep primary contacts first and sort contacts alphabetically
  // within the same priority.
  List<EmergencyContact> _sortContacts(Iterable<EmergencyContact> contacts) {
    final sorted = contacts.toList();

    sorted.sort((a, b) {
      final aPriority = a.priority == 'primary' ? 0 : 1;
      final bPriority = b.priority == 'primary' ? 0 : 1;

      final priorityComparison = aPriority.compareTo(bPriority);

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    });

    return sorted;
  }

  Stream<List<EmergencyContact>> watchContacts() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<EmergencyContact>[]);
      }

      return _contactsRefFor(user.uid).snapshots().map((snapshot) {
        return _sortContacts(
          snapshot.docs.map(
            (doc) => EmergencyContact.fromMap(doc.id, doc.data()),
          ),
        );
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
        return _sortContacts(
          cached.docs.map(
            (doc) => EmergencyContact.fromMap(doc.id, doc.data()),
          ),
        );
      }
    } catch (_) {
      // No saved copy yet. Fall through to the server.
    }

    final snapshot = await ref.get().timeout(const Duration(seconds: 8));

    return _sortContacts(
      snapshot.docs.map((doc) => EmergencyContact.fromMap(doc.id, doc.data())),
    );
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
