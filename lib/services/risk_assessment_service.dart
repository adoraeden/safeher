import 'incident_service.dart';

enum RiskLevel { low, medium, high }

class RiskAssessment {
  final RiskLevel level;
  final double score;
  final int nearbyReportCount;

  RiskAssessment({
    required this.level,
    required this.score,
    required this.nearbyReportCount,
  });
}

RiskLevel levelForScore(double score) {
  if (score < 0.35) return RiskLevel.low;
  if (score < 0.65) return RiskLevel.medium;
  return RiskLevel.high;
}

double hourRiskComponent(int hour) {
  if (hour >= 22 || hour <= 4) return 1.0;
  if (hour >= 18) return 0.5;
  return 0.1;
}

class RiskAssessmentService {
  final _incidentService = IncidentService();

  Future<RiskAssessment> assessCurrentRisk({
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now();
    final hourComponent = hourRiskComponent(now.hour);
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    final nearbyCount = await _incidentService.countNearbyReports(
      lat: lat,
      lng: lng,
      radiusKm: 1.0,
      withinDays: 30,
    );

    final reportComponent = (nearbyCount / 8).clamp(0.0, 1.0);
    final score =
        ((0.5 * hourComponent) +
                (0.2 * (isWeekend ? 1.0 : 0.0)) +
                (0.3 * reportComponent))
            .clamp(0.0, 1.0);

    return RiskAssessment(
      level: levelForScore(score),
      score: score,
      nearbyReportCount: nearbyCount,
    );
  }
}
