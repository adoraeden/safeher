import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'auth_helpers.dart';

class LocationShareService {
  final FirebaseFirestore? firestore;

  LocationShareService({this.firestore});

  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSub;
  String? _activeSessionId;

  bool get isActive => _activeSessionId != null;

  /// Formats GPS coordinates into a universal map URL.
  /// Works across all mobile devices, web browsers, Google Maps, Apple Maps, and default map handlers.
  /// Never contains localhost, 127.0.0.1, or local server addresses.
  static String formatMapUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Builds a human-readable sharing message including the universal map URL.
  static String buildShareMessage({
    required double latitude,
    required double longitude,
    String? name,
  }) {
    final mapUrl = formatMapUrl(latitude, longitude);
    final prefix = (name != null && name.trim().isNotEmpty)
        ? '$name has shared their current location with you via SafeHer:'
        : 'Here is my current location via SafeHer:';
    return '$prefix\n$mapUrl';
  }

  /// Requests permissions if needed and retrieves the device's actual GPS position.
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are turned off. Please turn on GPS in your device settings to share your location.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. SafeHer needs location permission to share your current location.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Please enable location permissions for SafeHer in your device settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Starts a live location sharing session in Firestore and streams position updates.
  Future<String> startSharing({
    required String sharerName,
    required Duration duration,
  }) async {
    final uid = await requireUid();
    final sessionId = const Uuid().v4();
    final expiresAt = DateTime.now().add(duration);
    final initialPosition = await getCurrentLocation();
    final mapUrl = formatMapUrl(initialPosition.latitude, initialPosition.longitude);

    await _firestore.collection('location_shares').doc(sessionId).set({
      'sharerId': uid,
      'sharerName': sharerName,
      'lat': initialPosition.latitude,
      'lng': initialPosition.longitude,
      'mapUrl': mapUrl,
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'active': true,
    });

    _activeSessionId = sessionId;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((position) {
      _firestore.collection('location_shares').doc(sessionId).update({
        'lat': position.latitude,
        'lng': position.longitude,
        'mapUrl': formatMapUrl(position.latitude, position.longitude),
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
