class SafetyMarker {
  final String id;
  final String name;
  final String type; // 'police', 'hospital', 'shelter'
  final double lat;
  final double lng;
  final String description;
  final String? phone;

  SafetyMarker({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.description,
    this.phone,
  });
}
