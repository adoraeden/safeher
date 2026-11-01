import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/emergency_contact.dart';
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

    // Use a recent cached location immediately if it is under one minute old.
    final last = await Geolocator.getLastKnownPosition();

    if (last != null) {
      final age = DateTime.now().difference(last.timestamp);

      if (!age.isNegative && age <= const Duration(minutes: 1)) {
        return last;
      }
    }

    // Otherwise request a fresh GPS position with a time limit.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // A last-known location is acceptable only when it is no more
      // than five minutes old.
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp);

        if (!age.isNegative && age <= const Duration(minutes: 5)) {
          return last;
        }
      }

      rethrow;
    }
  }

  Future<EmergencyEvent> triggerSos({
    String source = 'manual',
    String? phrase,
  }) async {
    final uid = await requireUid();
    final clock = Stopwatch()..start();

    // SMS must go out even if the location cannot be found.
    Position? position;

    try {
      position = await _getCurrentLocation();
    } catch (e) {
      debugPrint('[SOS] Could not get a location: $e');
    }

    debugPrint(
      '[SOS] location step finished after ${clock.elapsedMilliseconds} ms (found: ${position != null})',
    );

    List<EmergencyContact> contacts = [];

    try {
      contacts = await _contactsService.getContactsOnce();
    } catch (e) {
      debugPrint('[SOS] Could not load contacts: $e');
    }

    final notifyList = contacts.where((c) => c.notifyOnSos).toList();

    final name = FirebaseAuth.instance.currentUser?.displayName;

    final who = (name == null || name.trim().isEmpty)
        ? 'A SafeHer user'
        : name.trim();

    final String message;

    if (position != null) {
      final mapUrl = LocationShareService.formatMapUrl(
        position.latitude,
        position.longitude,
      );

      final coords =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';

      final age = DateTime.now().difference(position.timestamp);

      final isRecent = age.isNegative || age <= const Duration(minutes: 1);

      final locationLabel = isRecent
          ? 'Recent GPS location'
          : 'Last known location (approximately '
                '${(age.inSeconds / 60).ceil()} minutes old)';

      message =
          '$who needs help! SOS triggered from SafeHer. '
          '$locationLabel: $mapUrl ($coords)';
    } else {
      message =
          '$who needs help! SOS triggered from SafeHer, but the '
          'location could not be retrieved. Please call me back '
          'immediately or contact me directly.';
    }

    // SMS must never stop the SOS, so every failure is caught here.
    bool canSms = false;

    if (sendRealSms) {
      try {
        canSms = await _sms.hasPermission();
      } catch (e) {
        debugPrint('[SOS] SMS permission check failed: $e');
      }
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
      'lat': position?.latitude ?? 0.0,
      'lng': position?.longitude ?? 0.0,
      'locationFound': position != null,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'ACTIVE',
      'source': source,
      'triggerPhrase': ?phrase,
      'notifiedContacts': notifiedContacts,
    };

    // Save in the background. Offline, Firestore keeps the record and uploads
    // it later, so SOS must never wait for it.
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_events')
        .doc();

    docRef.set(data).catchError((Object e) {
      debugPrint('[SOS] Could not save the event yet: $e');
    });

    return EmergencyEvent.fromMap(docRef.id, data);
  }

  Future<void> resolveSos(String eventId) async {
    final uid = await requireUid();

    // Do not wait for the server forever. Offline, the update is kept
    // and uploaded later.
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_events')
        .doc(eventId)
        .update({
          'status': 'RESOLVED',
          'resolvedAt': DateTime.now().toIso8601String(),
        })
        .timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  Stream<List<EmergencyEvent>> watchEvents() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<EmergencyEvent>[]);
      }

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
