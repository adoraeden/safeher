import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'incident_service.dart';
import '../models/incident_report.dart';
import '../utils/geo_utils.dart';

enum TravelMode { walk, car }

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
  final TravelMode mode;

  RouteCheckResult({
    required this.path,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.nearbyReportCount,
    required this.safetyNote,
    this.mode = TravelMode.walk,
  });
}

class RouteService {
  final _incidentService = IncidentService();

  // Walking uses the dedicated walking server only. A car server would give a
  // wrong route here, so there is no backup for walking.
  static const _walkBases = [
    'https://routing.openstreetmap.de/routed-foot/route/v1/foot',
  ];
  static const _carBases = [
    'https://router.project-osrm.org/route/v1/driving',
    'https://routing.openstreetmap.de/routed-car/route/v1/driving',
  ];

  // Walking pace used for the time estimate: 5 km/h.
  static const _walkMetersPerSecond = 5000 / 3600;

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
    List<String> bases,
    RoutePoint from,
    RoutePoint to,
  ) async {
    for (final base in bases) {
      try {
        final uri = Uri.parse(
          '$base/${from.lng},${from.lat};${to.lng},${to.lat}?geometries=geojson&overview=full',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));
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
    TravelMode mode = TravelMode.walk,
  }) async {
    final route = await _fetchRoute(
      mode == TravelMode.car ? _carBases : _walkBases,
      from,
      to,
    );
    if (route == null) {
      throw Exception(
        mode == TravelMode.car
            ? 'Could not find a driving route right now. Check your internet and try again.'
            : 'Could not find a walking route right now. Check your internet and try again.',
      );
    }

    final coords = (route['geometry']['coordinates'] as List)
        .map(
          (c) => RoutePoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        )
        .toList();

    final distance = (route['distance'] as num).toDouble();

    // Walking time comes from the distance, not from the server.
    final double duration;
    if (mode == TravelMode.walk) {
      duration = distance / _walkMetersPerSecond;
    } else {
      final serverDuration = (route['duration'] as num?)?.toDouble() ?? 0;
      duration = serverDuration > 0 ? serverDuration : distance / 7.0;
    }

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
      distanceMeters: distance,
      durationSeconds: duration,
      nearbyReportCount: nearbyCount,
      safetyNote: note,
      mode: mode,
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
