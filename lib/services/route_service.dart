import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'incident_service.dart';
import '../models/incident_report.dart';
import '../utils/geo_utils.dart';

class RoutePoint {
  final double lat;
  final double lng;
  RoutePoint(this.lat, this.lng);
}

class RouteCheckResult {
  final List<RoutePoint> path;
  final double distanceMeters;
  final double durationSeconds;
  final int nearbyReportCount;
  final String safetyNote;

  RouteCheckResult({
    required this.path,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.nearbyReportCount,
    required this.safetyNote,
  });
}

class RouteService {
  final _incidentService = IncidentService();

  // The dedicated walking server first, then the general demo server.
  static const _routeBases = [
    'https://routing.openstreetmap.de/routed-foot/route/v1/foot',
    'https://router.project-osrm.org/route/v1/foot',
  ];

  Future<RoutePoint?> geocodeAddress(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'com.safeher.women_safety (college project)'},
    );
    if (response.statusCode != 200) return null;
    final results = jsonDecode(response.body) as List;
    if (results.isEmpty) return null;
    final first = results.first;
    return RoutePoint(double.parse(first['lat']), double.parse(first['lon']));
  }

  Future<Map<String, dynamic>?> _fetchRoute(
    RoutePoint from,
    RoutePoint to,
  ) async {
    for (final base in _routeBases) {
      try {
        final uri = Uri.parse(
          '$base/${from.lng},${from.lat};${to.lng},${to.lat}?geometries=geojson&overview=full',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          return data['routes'][0] as Map<String, dynamic>;
        }
      } catch (_) {
        // Try the next server.
      }
    }
    return null;
  }

  Future<RouteCheckResult> checkRoute({
    required RoutePoint from,
    required RoutePoint to,
  }) async {
    final route = await _fetchRoute(from, to);
    if (route == null) {
      throw Exception(
        'Could not find a walking route right now. Check your internet and try again.',
      );
    }

    final coords = (route['geometry']['coordinates'] as List)
        .map(
          (c) => RoutePoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        )
        .toList();

    final reports = await _incidentService.getRecentReports(withinDays: 30);
    final nearbyCount = _countReportsNearPath(
      coords,
      reports,
      bufferMeters: 200,
    );

    String note;
    if (nearbyCount == 0) {
      note = 'Lower reported incident level along this route, based on available community data.';
    } else if (nearbyCount <= 2) {
      note = 'Some reported activity along this route in the last 30 days.';
    } else {
      note = 'Elevated reported incident level along this route in the last 30 days.';
    }

    return RouteCheckResult(
      path: coords,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      nearbyReportCount: nearbyCount,
      safetyNote: note,
    );
  }

  int _countReportsNearPath(
    List<RoutePoint> path,
    List<IncidentReport> reports, {
    required double bufferMeters,
  }) {
    final sampled = <RoutePoint>[];
    final step = max(1, (path.length / 40).round());
    for (var i = 0; i < path.length; i += step) {
      sampled.add(path[i]);
    }
    int count = 0;
    for (final report in reports) {
      if (report.lat == null || report.lng == null) continue;
      final tooClose = sampled.any(
        (p) =>
            haversineMeters(p.lat, p.lng, report.lat!, report.lng!) <=
            bufferMeters,
      );
      if (tooClose) count++;
    }
    return count;
  }
}
