import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/models/incident_report.dart';

void main() {
  group('Report Hazard - IncidentReport Model Tests', () {
    test('creates full structured report and round-trips via toMap / fromMap', () {
      final occurred = DateTime.parse('2026-09-20T17:30:00.000');
      final created = DateTime.parse('2026-09-20T17:45:00.000');

      final report = IncidentReport(
        id: 'rep_123',
        category: 'infrastructure',
        type: 'poor_lighting',
        description: 'Streetlights are completely off near the alleyway.',
        severity: 'high',
        isActive: true,
        occurredAt: occurred,
        lat: 12.9716,
        lng: 77.5946,
        locationName: 'Opposite Metro Gate 2',
        additionalNotes: 'Walk on the main road instead of taking the shortcut.',
        timestamp: created,
        reporterId: 'user_safeher_456',
      );

      final map = report.toMap();

      expect(map['category'], 'infrastructure');
      expect(map['type'], 'poor_lighting');
      expect(map['description'], 'Streetlights are completely off near the alleyway.');
      expect(map['severity'], 'high');
      expect(map['isActive'], true);
      expect(map['occurredAt'], occurred.toIso8601String());
      expect(map['lat'], 12.9716);
      expect(map['lng'], 77.5946);
      expect(map['locationName'], 'Opposite Metro Gate 2');
      expect(map['additionalNotes'], 'Walk on the main road instead of taking the shortcut.');
      expect(map['timestamp'], created.toIso8601String());
      expect(map['reporterId'], 'user_safeher_456');

      final parsed = IncidentReport.fromMap('rep_123', map);

      expect(parsed.id, 'rep_123');
      expect(parsed.category, 'infrastructure');
      expect(parsed.type, 'poor_lighting');
      expect(parsed.description, report.description);
      expect(parsed.severity, 'high');
      expect(parsed.isActive, true);
      expect(parsed.occurredAt, occurred);
      expect(parsed.lat, 12.9716);
      expect(parsed.lng, 77.5946);
      expect(parsed.locationName, 'Opposite Metro Gate 2');
      expect(parsed.additionalNotes, report.additionalNotes);
      expect(parsed.timestamp, created);
      expect(parsed.reporterId, 'user_safeher_456');
    });

    test('preserves backwards compatibility with legacy map lacking new fields', () {
      final legacyMap = {
        'type': 'harassment',
        'description': 'Verbal harassment on bus stop',
        'lat': 37.7749,
        'lng': -122.4194,
        'timestamp': '2026-09-15T12:00:00.000',
        'reporterId': 'user_legacy_001',
      };

      final parsed = IncidentReport.fromMap('legacy_doc_1', legacyMap);

      expect(parsed.id, 'legacy_doc_1');
      expect(parsed.type, 'harassment');
      // Category defaults to type
      expect(parsed.category, 'harassment');
      expect(parsed.description, 'Verbal harassment on bus stop');
      expect(parsed.lat, 37.7749);
      expect(parsed.lng, -122.4194);
      // Defaults
      expect(parsed.severity, 'medium');
      expect(parsed.isActive, true);
      expect(parsed.occurredAt, isNull);
      expect(parsed.locationName, isNull);
      expect(parsed.additionalNotes, isNull);
      expect(parsed.reporterId, 'user_legacy_001');
    });

    test('handles report without location coordinates gracefully', () {
      final report = IncidentReport(
        id: 'no_loc_1',
        type: 'suspicious_activity',
        description: 'Unidentified vehicle trailing women walking alone.',
        timestamp: DateTime.now(),
        reporterId: 'user_789',
        severity: 'critical',
        isActive: false,
      );

      final map = report.toMap();
      expect(map.containsKey('lat'), false);
      expect(map.containsKey('lng'), false);
      expect(map.containsKey('locationName'), false);
      expect(map.containsKey('additionalNotes'), false);

      final parsed = IncidentReport.fromMap('no_loc_1', map);
      expect(parsed.lat, isNull);
      expect(parsed.lng, isNull);
      expect(parsed.locationName, isNull);
      expect(parsed.additionalNotes, isNull);
      expect(parsed.severity, 'critical');
      expect(parsed.isActive, false);
      expect(parsed.category, 'suspicious_activity');
    });

    test('trims whitespace on locationName and additionalNotes during toMap', () {
      final report = IncidentReport(
        id: 'trim_1',
        type: 'other',
        description: 'Valid description of hazard',
        locationName: '   Main Street Corner   ',
        additionalNotes: '   Take alternative route   ',
        timestamp: DateTime.now(),
        reporterId: 'user_trim',
      );

      final map = report.toMap();
      expect(map['locationName'], 'Main Street Corner');
      expect(map['additionalNotes'], 'Take alternative route');
    });

    test('omits empty whitespace-only locationName and additionalNotes', () {
      final report = IncidentReport(
        id: 'empty_opt_1',
        type: 'other',
        description: 'Valid description of hazard',
        locationName: '    ',
        additionalNotes: '  ',
        timestamp: DateTime.now(),
        reporterId: 'user_empty',
      );

      final map = report.toMap();
      expect(map.containsKey('locationName'), false);
      expect(map.containsKey('additionalNotes'), false);
    });
  });
}
