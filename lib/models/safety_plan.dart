class SafetyPlan {
  final List<String> safePlaces;
  final String personalNotes;
  final Map<String, bool> checklist;

  SafetyPlan({
    required this.safePlaces,
    required this.personalNotes,
    required this.checklist,
  });

  static const Map<String, bool> defaultChecklist = {
    'Shared my location with a trusted contact before heading out': false,
    'Phone is charged above 50%': false,
    'Emergency contacts are up to date': false,
    'I know the way to my nearest listed safe place': false,
  };

  factory SafetyPlan.empty() => SafetyPlan(
    safePlaces: [],
    personalNotes: '',
    checklist: Map.from(defaultChecklist),
  );

  factory SafetyPlan.fromMap(Map<String, dynamic> map) {
    final rawChecklist = map['checklist'] as Map<String, dynamic>?;
    return SafetyPlan(
      safePlaces: List<String>.from(map['safePlaces'] ?? []),
      personalNotes: map['personalNotes'] ?? '',
      checklist: rawChecklist != null
          ? rawChecklist.map((k, v) => MapEntry(k, v as bool))
          : Map.from(defaultChecklist),
    );
  }

  Map<String, dynamic> toMap() => {
    'safePlaces': safePlaces,
    'personalNotes': personalNotes,
    'checklist': checklist,
  };
}
