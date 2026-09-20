import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'auth_helpers.dart';

class LocationShareService {
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSub;
  String? _activeSessionId;

  bool get isActive => _activeSessionId != null;

  Future<String> startSharing({
    required String sharerName,
    required Duration duration,
  }) async {
    final uid = await requireUid();
    final sessionId = const Uuid().v4();
    final expiresAt = DateTime.now().add(duration);
    final initialPosition = await Geolocator.getCurrentPosition();

    await _firestore.collection('location_shares').doc(sessionId).set({
      'sharerId': uid,
      'sharerName': sharerName,
      'lat': initialPosition.latitude,
      'lng': initialPosition.longitude,
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'active': true,
    });

    _activeSessionId = sessionId;

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          ),
        ).listen((position) {
          _firestore.collection('location_shares').doc(sessionId).update({
            'lat': position.latitude,
            'lng': position.longitude,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        });

    return sessionId;
  }

  Future<void> stopSharing() async {
    if (_activeSessionId == null) return;
    await _firestore.collection('location_shares').doc(_activeSessionId).update(
      {'active': false},
    );
    await _positionSub?.cancel();
    _positionSub = null;
    _activeSessionId = null;
  }
}
