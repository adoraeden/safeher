import 'dart:math';

import 'incident_service.dart';

enum RiskLevel { low, moderate, elevated }

class RiskAssessment {
  final RiskLevel level;
  final int score;
  final int nearbyIncidentCount;
  final String timeFactor;

  RiskAssessment({
    required this.level,
    required this.score,
    required this.nearbyIncidentCount,
    required this.timeFactor,
  });
}

class RiskService {
  final _incidentService = IncidentService();

  /// A transparent, rule-based indicator — not a machine-learning model.
  /// Every factor is visible to the user, unlike a black-box prediction.
  /// The ML classifier built in the Phase 7 Colab notebook stays a separate,
  /// clearly-labeled research component rather than driving this live score
  /// — see that notebook's Limitations section for why.
  Future<RiskAssessment> assess({
    required double? lat,
    required double? lng,
  }) async {
    final now = DateTime.now();
    final hour = now.hour;

    int score = 0;
    String timeFactor;
    if (hour >= 0 && hour < 5) {
      score += 3;
      timeFactor = 'Late night (12–5am)';
    } else if (hour >= 5 && hour < 8) {
      score += 1;
      timeFactor = 'Early morning (5–8am)';
    } else if (hour >= 18 && hour < 22) {
      score += 1;
      timeFactor = 'Evening (6–10pm)';
    } else if (hour >= 22) {
      score += 2;
      timeFactor = 'Night (10pm–12am)';
    } else {
      timeFactor = 'Daytime';
    }

    int nearbyCount = 0;
    if (lat != null && lng != null) {
      final reports = await _incidentService.watchAllReports().first;
      final cutoff = now.subtract(const Duration(days: 14));
      nearbyCount = reports.where((r) {
        if (r.lat == null || r.lng == null) return false;
        if (r.timestamp.isBefore(cutoff)) return false;
        return _haversineKm(lat, lng, r.lat!, r.lng!) <= 2.0;
      }).length;
      score += min(nearbyCount * 2, 6);
    }

    final level = score >= 6
        ? RiskLevel.elevated
        : score >= 3
        ? RiskLevel.moderate
        : RiskLevel.low;

    return RiskAssessment(
      level: level,
      score: score,
      nearbyIncidentCount: nearbyCount,
      timeFactor: timeFactor,
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (pi / 180);
}
