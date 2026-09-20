import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/services/risk_assessment_service.dart';

void main() {
  group('levelForScore', () {
    test('scores below 0.35 are low risk', () {
      expect(levelForScore(0.0), RiskLevel.low);
      expect(levelForScore(0.34), RiskLevel.low);
    });

    test('scores from 0.35 up to (not including) 0.65 are medium risk', () {
      expect(levelForScore(0.35), RiskLevel.medium);
      expect(levelForScore(0.5), RiskLevel.medium);
      expect(levelForScore(0.64), RiskLevel.medium);
    });

    test('scores 0.65 and above are high risk', () {
      expect(levelForScore(0.65), RiskLevel.high);
      expect(levelForScore(1.0), RiskLevel.high);
    });
  });

  group('hourRiskComponent', () {
    test('late night hours score highest', () {
      expect(hourRiskComponent(23), 1.0);
      expect(hourRiskComponent(2), 1.0);
    });

    test('evening hours score medium', () {
      expect(hourRiskComponent(19), 0.5);
    });

    test('daytime hours score lowest', () {
      expect(hourRiskComponent(12), 0.1);
    });
  });
}
