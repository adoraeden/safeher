class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final String priority; // 'primary' or 'secondary'
  final bool notifyOnSos;
  final String? email;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.priority,
    required this.notifyOnSos,
    this.email,
  });

  factory EmergencyContact.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyContact(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'] ?? '',
      priority: map['priority'] ?? 'secondary',
      notifyOnSos: map['notifyOnSos'] ?? true,
      email: map['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': priority,
      'notifyOnSos': notifyOnSos,
      if (email != null && email!.trim().isNotEmpty) 'email': email,
    };
  }
}
