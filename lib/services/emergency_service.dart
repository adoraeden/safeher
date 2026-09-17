import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/emergency_event.dart';
import 'auth_helpers.dart';
import 'contacts_service.dart';

class EmergencyService {
  final _firestore = FirebaseFirestore.instance;
  final _contactsService = ContactsService();

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

    return Geolocator.getCurrentPosition();
  }

  Future<EmergencyEvent> triggerSos() async {
    final uid = await requireUid();
    final position = await _getCurrentLocation();
    final contacts = await _contactsService.getContactsOnce();
    final notifyList = contacts.where((c) => c.notifyOnSos).toList();

    final notifiedContacts = notifyList
        .map((c) => {'name': c.name, 'phone': c.phone, 'demo': true})
        .toList();

    final data = {
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'ACTIVE',
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
}
