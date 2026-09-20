class EmergencyEvent {
  final String id;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String status; // 'ACTIVE', 'RESOLVED', 'CANCELLED'
  final List<Map<String, dynamic>> notifiedContacts;

  EmergencyEvent({
    required this.id,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.status,
    required this.notifiedContacts,
  });

  factory EmergencyEvent.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyEvent(
      id: id,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? 'ACTIVE',
      notifiedContacts: List<Map<String, dynamic>>.from(
        map['notifiedContacts'] ?? [],
      ),
    );
  }
}
