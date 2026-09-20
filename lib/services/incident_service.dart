import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/incident_report.dart';
import '../utils/geo_utils.dart';
import 'auth_helpers.dart';

class IncidentService {
  final FirebaseFirestore? firestore;

  IncidentService({this.firestore});

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _db.collection('incident_reports');

  Stream<List<IncidentReport>> watchAllReports() {
    return _reportsRef
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<IncidentReport>> getRecentReports({
    required int withinDays,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: withinDays));
    final snapshot = await _reportsRef
        .where('timestamp', isGreaterThan: cutoff.toIso8601String())
        .get();
    return snapshot.docs
        .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> submitReport({
    required String type,
    String? category,
    required String description,
    String severity = 'medium',
    bool isActive = true,
    DateTime? occurredAt,
    double? lat,
    double? lng,
    String? locationName,
    String? additionalNotes,
  }) async {
    final uid = await requireUid();
    final report = IncidentReport(
      id: '',
      type: type,
      category: category ?? type,
      description: description,
      lat: lat,
      lng: lng,
      timestamp: DateTime.now(),
      reporterId: uid,
      severity: severity,
      isActive: isActive,
      occurredAt: occurredAt ?? DateTime.now(),
      locationName: locationName,
      additionalNotes: additionalNotes,
    );
    await _reportsRef.add(report.toMap());
  }

  Future<int> countNearbyReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required int withinDays,
  }) async {
    final reports = await getRecentReports(withinDays: withinDays);
    int count = 0;
    for (final report in reports) {
      if (report.lat == null || report.lng == null) continue;
      final distance = haversineKm(lat, lng, report.lat!, report.lng!);
      if (distance <= radiusKm) count++;
    }
    return count;
  }
}
