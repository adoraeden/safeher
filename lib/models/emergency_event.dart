class EmergencyEvent {
  final String id;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String status; // 'ACTIVE', 'RESOLVED', 'CANCELLED'
  final String source; // 'manual', 'voice', 'shake'
  final String? triggerPhrase;
  final List<Map<String, dynamic>> notifiedContacts;

  EmergencyEvent({
    required this.id,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.status,
    this.source = 'manual',
    this.triggerPhrase,
    required this.notifiedContacts,
  });

  factory EmergencyEvent.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyEvent(
      id: id,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? 'ACTIVE',
      source: map['source']?.toString() ?? 'manual',
      triggerPhrase: map['triggerPhrase']?.toString(),
      notifiedContacts: List<Map<String, dynamic>>.from(
        map['notifiedContacts'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'source': source,
    if (triggerPhrase != null) 'triggerPhrase': triggerPhrase,
    'notifiedContacts': notifiedContacts,
  };
}
