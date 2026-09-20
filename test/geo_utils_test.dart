import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/utils/geo_utils.dart';

void main() {
  group('haversineKm', () {
    test('distance from a point to itself is zero', () {
      expect(
        haversineKm(37.7749, -122.4194, 37.7749, -122.4194),
        closeTo(0, 0.0001),
      );
    });

    test('known distance: San Francisco to Los Angeles is roughly 559 km', () {
      final distance = haversineKm(37.7749, -122.4194, 34.0522, -118.2437);
      expect(distance, closeTo(559, 15));
    });

    test('is symmetric — order of points does not matter', () {
      final a = haversineKm(37.7749, -122.4194, 34.0522, -118.2437);
      final b = haversineKm(34.0522, -118.2437, 37.7749, -122.4194);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('haversineMeters', () {
    test('is 1000x the kilometer value', () {
      final km = haversineKm(37.7749, -122.4194, 34.0522, -118.2437);
      final m = haversineMeters(37.7749, -122.4194, 34.0522, -118.2437);
      expect(m, closeTo(km * 1000, 0.01));
    });
  });
}
