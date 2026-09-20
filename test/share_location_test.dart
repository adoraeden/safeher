import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:women_safety/models/emergency_contact.dart';
import 'package:women_safety/screens/location/live_location_screen.dart';
import 'package:women_safety/services/location_share_service.dart';

class FakeLocationShareService extends LocationShareService {
  Position? mockPosition;
  bool shouldThrow = false;
  String throwMessage =
      'Location services are turned off. Please turn on GPS in your device settings to share your location.';

  @override
  Future<Position> getCurrentLocation() async {
    if (shouldThrow) {
      throw Exception(throwMessage);
    }
    return mockPosition ??
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 1.0,
        );
  }
}

void main() {
  group('LocationShareService - Universal Map URL Generation', () {
    test('generates valid Google Maps search URL for standard coordinates', () {
      final url = LocationShareService.formatMapUrl(37.774929, -122.419416);
      expect(
        url,
        'https://www.google.com/maps/search/?api=1&query=37.774929,-122.419416',
      );
    });

    test('generates valid URL for southern/eastern hemisphere coordinates', () {
      final url = LocationShareService.formatMapUrl(-33.86882, 151.209296);
      expect(
        url,
        'https://www.google.com/maps/search/?api=1&query=-33.86882,151.209296',
      );
    });

    test('generates valid URL for (0, 0) coordinates', () {
      final url = LocationShareService.formatMapUrl(0.0, 0.0);
      expect(
        url,
        'https://www.google.com/maps/search/?api=1&query=0.0,0.0',
      );
    });

    test('URL is parseable as a valid HTTPS URI', () {
      final url = LocationShareService.formatMapUrl(12.971598, 77.594562);
      final uri = Uri.tryParse(url);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '12.971598,77.594562');
    });

    test('URL strictly does NOT contain localhost, 127.0.0.1, or local ports', () {
      final testCoords = [
        [37.7749, -122.4194],
        [28.6139, 77.2090],
        [51.5074, -0.1278],
        [0.0, 0.0],
      ];

      for (final pair in testCoords) {
        final url = LocationShareService.formatMapUrl(pair[0], pair[1]);
        expect(url.contains('localhost'), isFalse, reason: 'URL must not contain localhost');
        expect(url.contains('127.0.0.1'), isFalse, reason: 'URL must not contain 127.0.0.1');
        expect(url.contains('192.168.'), isFalse, reason: 'URL must not contain local IP');
        expect(url.contains(':5000'), isFalse, reason: 'URL must not contain local port 5000');
        expect(url.contains('/share.html'), isFalse, reason: 'URL must not contain internal app routes');
      }
    });
  });

  group('LocationShareService - Share Message Builder', () {
    test('builds message with sharer name when provided', () {
      final message = LocationShareService.buildShareMessage(
        latitude: 37.7749,
        longitude: -122.4194,
        name: 'Jane Doe',
      );

      expect(message, contains('Jane Doe has shared their current location'));
      expect(message, contains('https://www.google.com/maps/search/?api=1&query=37.7749,-122.4194'));
    });

    test('builds message with default phrasing when name is omitted or empty', () {
      final messageWithoutName = LocationShareService.buildShareMessage(
        latitude: 37.7749,
        longitude: -122.4194,
      );
      expect(messageWithoutName, contains('Here is my current location via SafeHer:'));
      expect(messageWithoutName, contains('https://www.google.com/maps/search/?api=1&query=37.7749,-122.4194'));

      final messageWithEmptyName = LocationShareService.buildShareMessage(
        latitude: 37.7749,
        longitude: -122.4194,
        name: '   ',
      );
      expect(messageWithEmptyName, contains('Here is my current location via SafeHer:'));
    });

    test('share message contains a valid openable URL', () {
      final message = LocationShareService.buildShareMessage(
        latitude: 19.0760,
        longitude: 72.8777,
        name: 'Priya',
      );

      final lines = message.split('\n');
      final urlLine = lines.lastWhere((line) => line.startsWith('https://'));
      final uri = Uri.parse(urlLine);
      expect(uri.isScheme('https'), isTrue);
      expect(uri.host, 'www.google.com');
    });
  });

  group('LiveLocationScreen - Widget & Interaction Tests', () {
    testWidgets('renders Share Location screen with all required sections and no local links', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeLocationService = FakeLocationShareService();
      final contactsStream = Stream.value([
        EmergencyContact(
          id: 'c1',
          name: 'Alice Smith',
          phone: '+1234567890',
          relationship: 'Sister',
          priority: 'primary',
          notifyOnSos: true,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveLocationScreen(
            service: fakeLocationService,
            contactsStream: contactsStream,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify headers and sections
      expect(find.text('Share Location'), findsOneWidget);
      expect(find.text('Share Current Location'), findsOneWidget);
      expect(find.text('Get & Share Current Location'), findsOneWidget);
      expect(find.text('Share with Emergency Contacts'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Timed Live Location Sharing'), findsOneWidget);

      // 2. Verify complete absence of legacy localhost / local server strings
      expect(find.textContaining('localhost'), findsNothing);
      expect(find.textContaining('127.0.0.1'), findsNothing);
      expect(find.textContaining('same network'), findsNothing);
      expect(find.textContaining('share.html'), findsNothing);
    });

    testWidgets('tapping Get & Share Current Location fetches GPS and displays real Google Maps URL', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeLocationService = FakeLocationShareService();
      final contactsStream = Stream.value(<EmergencyContact>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveLocationScreen(
            service: fakeLocationService,
            contactsStream: contactsStream,
          ),
        ),
      );

      await tester.pump();

      // Tap Get & Share Current Location button
      final getButton = find.text('Get & Share Current Location');
      expect(getButton, findsOneWidget);
      await tester.tap(getButton);

      // Pump to resolve async location fetch
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify GPS coordinates and Google Maps URL are rendered
      expect(find.textContaining('GPS: 37.774900, -122.419400'), findsOneWidget);
      expect(
        find.text('https://www.google.com/maps/search/?api=1&query=37.7749,-122.4194'),
        findsOneWidget,
      );

      // Verify action buttons appear
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('handles location error gracefully when GPS is disabled or permission is denied', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeLocationService = FakeLocationShareService()
        ..shouldThrow = true
        ..throwMessage =
            'Location permission was denied. SafeHer needs location permission to share your current location.';
      final contactsStream = Stream.value(<EmergencyContact>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveLocationScreen(
            service: fakeLocationService,
            contactsStream: contactsStream,
          ),
        ),
      );

      await tester.pump();

      // Tap Get & Share Current Location button
      await tester.tap(find.text('Get & Share Current Location'));

      // Pump to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify error banner is rendered on screen with the clear explanation
      expect(
        find.text(
          'Location permission was denied. SafeHer needs location permission to share your current location.',
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
