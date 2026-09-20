class IncidentReport {
  final String id;
  final String
  type; // 'harassment', 'unsafe_location', 'suspicious_activity', 'other'
  final String description;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  final String reporterId;

  IncidentReport({
    required this.id,
    required this.type,
    required this.description,
    this.lat,
    this.lng,
    required this.timestamp,
    required this.reporterId,
  });

  factory IncidentReport.fromMap(String id, Map<String, dynamic> map) {
    return IncidentReport(
      id: id,
      type: map['type'] ?? 'other',
      description: map['description'] ?? '',
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      reporterId: map['reporterId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'description': description,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'timestamp': timestamp.toIso8601String(),
      'reporterId': reporterId,
    };
  }
}
