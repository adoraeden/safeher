import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/models/emergency_contact.dart';
import 'package:women_safety/models/incident_report.dart';
import 'package:women_safety/models/emergency_event.dart';
import 'package:women_safety/models/user_profile.dart';
import 'package:women_safety/models/safety_plan.dart';

void main() {
  group('EmergencyContact', () {
    test('round-trips through toMap/fromMap', () {
      final original = EmergencyContact(
        id: 'c1',
        name: 'Jane Doe',
        phone: '555-1234',
        relationship: 'Sister',
        priority: 'primary',
        notifyOnSos: true,
      );
      final rebuilt = EmergencyContact.fromMap('c1', original.toMap());
      expect(rebuilt.name, original.name);
      expect(rebuilt.phone, original.phone);
      expect(rebuilt.priority, original.priority);
      expect(rebuilt.notifyOnSos, original.notifyOnSos);
    });

    test('missing optional email does not break parsing', () {
      final contact = EmergencyContact.fromMap('c2', {
        'name': 'Sam',
        'phone': '555-0000',
        'relationship': 'Friend',
        'priority': 'secondary',
        'notifyOnSos': false,
      });
      expect(contact.email, isNull);
    });
  });

  group('IncidentReport', () {
    test('round-trips including optional lat/lng', () {
      final original = IncidentReport(
        id: 'r1',
        type: 'harassment',
        description: 'Test report',
        lat: 37.77,
        lng: -122.41,
        timestamp: DateTime.parse('2026-01-01T10:00:00.000'),
        reporterId: 'u1',
      );
      final rebuilt = IncidentReport.fromMap('r1', original.toMap());
      expect(rebuilt.type, 'harassment');
      expect(rebuilt.lat, 37.77);
      expect(rebuilt.lng, -122.41);
    });

    test('handles a report with no location gracefully', () {
      final report = IncidentReport.fromMap('r2', {
        'type': 'other',
        'description': 'No location given',
        'timestamp': '2026-01-01T10:00:00.000',
        'reporterId': 'u1',
      });
      expect(report.lat, isNull);
      expect(report.lng, isNull);
    });
  });

  group('EmergencyEvent', () {
    test('parses a valid map correctly', () {
      final event = EmergencyEvent.fromMap('e1', {
        'lat': 37.77,
        'lng': -122.41,
        'timestamp': '2026-01-01T10:00:00.000',
        'status': 'ACTIVE',
        'notifiedContacts': [
          {'name': 'Jane', 'phone': '555-1234', 'demo': true},
        ],
      });
      expect(event.status, 'ACTIVE');
      expect(event.notifiedContacts.length, 1);
    });

    test('falls back sensibly on a missing timestamp', () {
      final event = EmergencyEvent.fromMap('e2', {
        'lat': 0.0,
        'lng': 0.0,
        'status': 'ACTIVE',
        'notifiedContacts': [],
      });
      expect(event.timestamp, isA<DateTime>());
    });
  });

  group('UserProfile', () {
    test('falls back to a default trigger phrase when none is set', () {
      final profile = UserProfile.fromMap({
        'name': 'Jane',
        'email': 'jane@example.com',
      });
      expect(profile.voiceTriggerPhrase, 'SafeHer help me');
    });
  });

  group('SafetyPlan', () {
    test('round-trips safe places and checklist', () {
      final original = SafetyPlan(
        safePlaces: ['Mom\'s house', 'Library'],
        personalNotes: 'No allergies',
        checklist: {'Test item': true},
      );
      final rebuilt = SafetyPlan.fromMap(original.toMap());
      expect(rebuilt.safePlaces, original.safePlaces);
      expect(rebuilt.checklist['Test item'], true);
    });

    test('empty() gives sensible defaults', () {
      final plan = SafetyPlan.empty();
      expect(plan.safePlaces, isEmpty);
      expect(plan.checklist.containsKey('Phone is charged above 50%'), true);
    });
  });
}
