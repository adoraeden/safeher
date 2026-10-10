class SafeHaven {
  final String name;
  final String address;
  final String notes;

  const SafeHaven({required this.name, this.address = '', this.notes = ''});

  factory SafeHaven.fromMap(Map<String, dynamic> map) => SafeHaven(
    name: (map['name'] ?? '').toString(),
    address: (map['address'] ?? '').toString(),
    notes: (map['notes'] ?? '').toString(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'notes': notes,
  };
}

class CommuteRoute {
  final String name;
  final String details;

  const CommuteRoute({required this.name, this.details = ''});

  factory CommuteRoute.fromMap(Map<String, dynamic> map) => CommuteRoute(
    name: (map['name'] ?? '').toString(),
    details: (map['details'] ?? '').toString(),
  );

  Map<String, dynamic> toMap() => {'name': name, 'details': details};
}

class SafetyPlan {
  final List<SafeHaven> safeHavens;
  final List<CommuteRoute> routes;
  final String medicalInfo;
  final String distressNotes;
  final String personalNotes;
  final Map<String, bool> checklist;

  SafetyPlan({
    List<SafeHaven>? safeHavens,
    List<String>? safePlaces,
    this.routes = const [],
    this.medicalInfo = '',
    this.distressNotes = '',
    this.personalNotes = '',
    required this.checklist,
  }) : safeHavens =
           safeHavens ??
           (safePlaces ?? const <String>[])
               .map((p) => SafeHaven(name: p))
               .toList();

  /// Names only, for any older code that still reads the plain list.
  List<String> get safePlaces => safeHavens.map((h) => h.name).toList();

  static const Map<String, bool> defaultChecklist = {
    'Shared my location with a trusted contact before heading out': false,
    'Phone is charged above 50%': false,
    'Emergency contacts are up to date': false,
    'I know the way to my nearest listed safe place': false,
    'I have tested SOS and Voice Guard while safe': false,
    'My medical info and distress code are filled in': false,
  };

  factory SafetyPlan.empty() => SafetyPlan(
    safeHavens: [],
    routes: [],
    medicalInfo: '',
    distressNotes: '',
    personalNotes: '',
    checklist: Map.from(defaultChecklist),
  );

  factory SafetyPlan.fromMap(Map<String, dynamic> map) {
    // Safe places: new structured list, or the old list of plain names.
    final havens = <SafeHaven>[];
    final rawHavens = map['safeHavens'];
    if (rawHavens is List) {
      for (final h in rawHavens) {
        if (h is Map) {
          havens.add(SafeHaven.fromMap(Map<String, dynamic>.from(h)));
        }
      }
    } else {
      for (final p in List<String>.from(map['safePlaces'] ?? [])) {
        havens.add(SafeHaven(name: p));
      }
    }

    final routes = <CommuteRoute>[];
    final rawRoutes = map['routes'];
    if (rawRoutes is List) {
      for (final r in rawRoutes) {
        if (r is Map) {
          routes.add(CommuteRoute.fromMap(Map<String, dynamic>.from(r)));
        }
      }
    }

    // Start from the defaults so new checklist items appear for old plans too.
    final checklist = Map<String, bool>.from(defaultChecklist);
    final rawChecklist = map['checklist'];
    if (rawChecklist is Map) {
      rawChecklist.forEach((k, v) {
        if (v is bool) checklist[k.toString()] = v;
      });
    }

    return SafetyPlan(
      safeHavens: havens,
      routes: routes,
      medicalInfo: (map['medicalInfo'] ?? '').toString(),
      distressNotes: (map['distressNotes'] ?? '').toString(),
      personalNotes: (map['personalNotes'] ?? '').toString(),
      checklist: checklist,
    );
  }

  Map<String, dynamic> toMap() => {
    'safeHavens': safeHavens.map((h) => h.toMap()).toList(),
    'safePlaces': safePlaces,
    'routes': routes.map((r) => r.toMap()).toList(),
    'medicalInfo': medicalInfo,
    'distressNotes': distressNotes,
    'personalNotes': personalNotes,
    'checklist': checklist,
  };
}
