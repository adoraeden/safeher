class IncidentReport {
  final String id;
  final String type; // specific hazard type
  final String category; // category grouping
  final String description;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  final String reporterId;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final bool isActive;
  final DateTime? occurredAt;
  final String? locationName;
  final String? additionalNotes;

  IncidentReport({
    required this.id,
    required this.type,
    String? category,
    required this.description,
    this.lat,
    this.lng,
    required this.timestamp,
    required this.reporterId,
    this.severity = 'medium',
    this.isActive = true,
    this.occurredAt,
    this.locationName,
    this.additionalNotes,
  }) : category = category ?? type;

  factory IncidentReport.fromMap(String id, Map<String, dynamic> map) {
    final type = map['type'] ?? 'other';
    return IncidentReport(
      id: id,
      type: type,
      category: map['category'] ?? type,
      description: map['description'] ?? '',
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      reporterId: map['reporterId'] ?? '',
      severity: map['severity'] ?? 'medium',
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      occurredAt: map['occurredAt'] != null
          ? DateTime.tryParse(map['occurredAt'].toString())
          : null,
      locationName: map['locationName'] as String?,
      additionalNotes: map['additionalNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'category': category,
      'description': description,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'timestamp': timestamp.toIso8601String(),
      'reporterId': reporterId,
      'severity': severity,
      'isActive': isActive,
      if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
      if (locationName != null && locationName!.trim().isNotEmpty)
        'locationName': locationName!.trim(),
      if (additionalNotes != null && additionalNotes!.trim().isNotEmpty)
        'additionalNotes': additionalNotes!.trim(),
    };
  }
}
