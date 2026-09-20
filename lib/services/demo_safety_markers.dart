import '../models/safety_marker.dart';

class DemoSafetyMarkers {
  // Illustrative DEMO markers, not real verified locations.
  // Real data comes from Incident Reporting (Phase 6).
  static List<SafetyMarker> around(double lat, double lng) {
    return [
      SafetyMarker(
        id: 'demo-police-1',
        name: 'Demo: Central Police Station',
        type: 'police',
        lat: lat + 0.004,
        lng: lng + 0.003,
        description: '24/7 designated assistance desk (demo data).',
        phone: '911',
      ),
      SafetyMarker(
        id: 'demo-hospital-1',
        name: 'Demo: City General Hospital',
        type: 'hospital',
        lat: lat - 0.003,
        lng: lng + 0.005,
        description: 'Emergency room, open 24/7 (demo data).',
        phone: '911',
      ),
      SafetyMarker(
        id: 'demo-shelter-1',
        name: 'Demo: Community Safe Shelter',
        type: 'shelter',
        lat: lat + 0.002,
        lng: lng - 0.004,
        description: "Women's safe shelter and support center (demo data).",
      ),
    ];
  }
}
