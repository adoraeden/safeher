import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/emergency_event.dart';
import 'auth_helpers.dart';
import 'contacts_service.dart';
import 'location_share_service.dart';
import 'sms_service.dart';

class EmergencyService {
  /// Set to false to go back to demo mode (no real SMS is sent on SOS).
  static const bool sendRealSms = true;

  final _firestore = FirebaseFirestore.instance;
  final _contactsService = ContactsService();
  final _sms = SmsService();

  Future<Position> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are turned off. Enable them to use SOS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied. SafeHer needs it to share your position during SOS.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in your device/browser settings.',
      );
    }

    // Use the phone's own recent position if it is under a minute old.
    // This is instant. Otherwise ask for a fresh GPS fix, with a time limit.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null &&
        DateTime.now().difference(last.timestamp).inSeconds < 60) {
      return last;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // A slightly old position is better than no position in an emergency.
      if (last != null) return last;
      rethrow;
    }
  }

  Future<EmergencyEvent> triggerSos({
    String source = 'manual',
    String? phrase,
  }) async {
    final uid = await requireUid();
    final clock = Stopwatch()..start();
    debugPrint('[SOS] getting location...');
    final position = await _getCurrentLocation();
    debugPrint('[SOS] got location after ${clock.elapsedMilliseconds} ms');
    final contacts = await _contactsService.getContactsOnce();
    final notifyList = contacts.where((c) => c.notifyOnSos).toList();

    final name = FirebaseAuth.instance.currentUser?.displayName;
    final who = (name == null || name.trim().isEmpty)
        ? 'A SafeHer user'
        : name.trim();
    final mapUrl = LocationShareService.formatMapUrl(
      position.latitude,
      position.longitude,
    );
    final message =
        '$who needs help! SOS triggered from SafeHer. '
        'Location: $mapUrl';

    // SMS must never stop the SOS, so every failure is caught here.
    bool canSms = false;
    if (sendRealSms) {
      try {
        canSms = await _sms.hasPermission();
      } catch (_) {}
    }

    final notifiedContacts = <Map<String, dynamic>>[];
    for (final c in notifyList) {
      bool sent = false;
      if (sendRealSms && canSms) {
        try {
          sent = await _sms.send(c.phone, message);
        } catch (e) {
          debugPrint('[SOS] SMS to ${c.name} failed: $e');
        }
      }
      notifiedContacts.add({
        'name': c.name,
        'phone': c.phone,
        'demo': !sendRealSms,
        'smsSent': sent,
      });
    }
    debugPrint('[SOS] SMS step done after ${clock.elapsedMilliseconds} ms');

    final data = {
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'ACTIVE',
      'source': source,
      'triggerPhrase': ?phrase,
      'notifiedContacts': notifiedContacts,
    };

    final docRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_events')
        .add(data);

    return EmergencyEvent.fromMap(docRef.id, data);
  }

  Future<void> resolveSos(String eventId) async {
    final uid = await requireUid();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_events')
        .doc(eventId)
        .update({
          'status': 'RESOLVED',
          'resolvedAt': DateTime.now().toIso8601String(),
        });
  }

  Stream<List<EmergencyEvent>> watchEvents() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<EmergencyEvent>[]);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_events')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => EmergencyEvent.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });
  }
}
