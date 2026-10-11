import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_helpers.dart';

class SavedPlace {
  final String key; // 'home' or 'work'
  final String name;
  final String address;
  final double lat;
  final double lng;

  const SavedPlace({
    required this.key,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory SavedPlace.fromMap(String key, Map<String, dynamic> map) =>
      SavedPlace(
        key: key,
        name: (map['name'] ?? '').toString(),
        address: (map['address'] ?? '').toString(),
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}

/// Home and Work, saved in the user's own account.
class SavedPlacesService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('savedPlaces');

  Stream<Map<String, SavedPlace>> watchPlaces() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<String, SavedPlace>{});
      return _col(user.uid).snapshots().map((snap) {
        final places = <String, SavedPlace>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['lat'] is num && data['lng'] is num) {
            places[doc.id] = SavedPlace.fromMap(doc.id, data);
          }
        }
        return places;
      });
    });
  }

  Future<void> savePlace(SavedPlace place) async {
    final uid = await requireUid();
    await _col(uid).doc(place.key).set(place.toMap());
  }

  Future<void> removePlace(String key) async {
    final uid = await requireUid();
    await _col(uid).doc(key).delete();
  }
}
