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

  Future<RouteCheckResult> checkRoute({
    required RoutePoint from,
    required RoutePoint to,
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/${from.lng},${from.lat};${to.lng},${to.lat}?geometries=geojson&overview=full',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Could not fetch a route right now.');
    }
    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('No walking route found between those points.');
    }

    final route = data['routes'][0];
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
