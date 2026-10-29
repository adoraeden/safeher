import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/safety_marker.dart';

/// Finds real police stations, hospitals and women's support centers near a
/// point, from OpenStreetMap data.
class NearbyPlacesService {
  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _userAgent = 'com.safeher.women_safety (college project)';

  static const _radiusMeters = 6000;
  static const _shelterRadiusMeters = 12000;
  static const _cacheMinutes = 10;

  // Remember the last result so moving around the map does not ask again.
  static String? _cacheKey;
  static DateTime? _cacheTime;
  static List<SafetyMarker> _cacheData = [];

  void _remember(String key, List<SafetyMarker> places) {
    _cacheKey = key;
    _cacheTime = DateTime.now();
    _cacheData = places;
  }

  Future<List<SafetyMarker>> fetchNearby(
    double lat,
    double lng, {
    bool forceRefresh = false,
  }) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (!forceRefresh &&
        _cacheKey == key &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < _cacheMinutes) {
      return _cacheData;
    }

    // True once any server has answered, even with an error. That tells us
    // the phone is online and the service is the problem.
    var reachedServer = false;

    final query =
        '''
[out:json][timeout:20][maxsize:33554432];
(nwr["amenity"="police"](around:$_radiusMeters,$lat,$lng););
out center 40;
(nwr["amenity"="hospital"](around:$_radiusMeters,$lat,$lng););
out center 40;
(nwr["amenity"="social_facility"]["social_facility:for"~"woman|women",i](around:$_shelterRadiusMeters,$lat,$lng););
out center 30;
''';

    // 1) Overpass: the full data, including phone numbers and opening hours.
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: const {
                'User-Agent': _userAgent,
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 15));
        reachedServer = true;

        if (response.statusCode != 200) {
          debugPrint('[Places] $endpoint answered ${response.statusCode}');
          continue;
        }
        final body = response.body.trimLeft();
        if (!body.startsWith('{')) {
          debugPrint('[Places] $endpoint sent a web page instead of data');
          continue;
        }
        final data = jsonDecode(body) as Map<String, dynamic>;
        final elements = (data['elements'] as List?) ?? const [];
        if (elements.isEmpty && data['remark'] != null) {
          debugPrint('[Places] $endpoint remark: ${data['remark']}');
          continue;
        }
        final places = _parse(elements);
        _remember(key, places);
        return places;
      } catch (e) {
        debugPrint('[Places] $endpoint failed: $e');
      }
    }

    // 2) Fallback: plain search for police stations and hospitals only.
    final fallback = await _nominatimFallback(lat, lng);
    if (fallback != null) reachedServer = true;
    if (fallback != null && fallback.isNotEmpty) {
      _remember(key, fallback);
      return fallback;
    }

    throw Exception(
      reachedServer
          ? 'The free map-data service is busy right now. Wait a minute and try again.'
          : 'Could not reach the map-data service. Check your internet connection and try again.',
    );
  }

  /// Returns null when no server answered at all.
  Future<List<SafetyMarker>?> _nominatimFallback(double lat, double lng) async {
    const d = 0.06; // roughly 6 to 7 km in each direction
    final viewbox = '${lng - d},${lat + d},${lng + d},${lat - d}';
    const searches = [('police', 'police station'), ('hospital', 'hospital')];

    final places = <SafetyMarker>[];
    var gotAnyResponse = false;

    for (var i = 0; i < searches.length; i++) {
      // The free service asks for no more than one request per second.
      if (i > 0) await Future.delayed(const Duration(milliseconds: 1100));
      final (type, term) = searches[i];
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': term,
          'format': 'jsonv2',
          'limit': '20',
          'viewbox': viewbox,
          'bounded': '1',
        });
        final response = await http
            .get(uri, headers: const {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          debugPrint('[Places] nominatim answered ${response.statusCode}');
          continue;
        }
        gotAnyResponse = true;
        final list = jsonDecode(response.body);
        if (list is! List) continue;

        for (final item in list) {
          if (item is! Map) continue;
          final plat = double.tryParse('${item['lat']}');
          final plng = double.tryParse('${item['lon']}');
          if (plat == null || plng == null) continue;

          final display = (item['display_name'] ?? '').toString();
          final rawName = (item['name'] ?? '').toString().trim();
          final name = rawName.isNotEmpty
              ? rawName
              : (display.isNotEmpty
                    ? display.split(',').first.trim()
                    : (type == 'police' ? 'Police station' : 'Hospital'));

          places.add(
            SafetyMarker(
              id: 'nominatim-${item['place_id']}',
              name: name,
              type: type,
              lat: plat,
              lng: plng,
              description: display.isEmpty
                  ? 'No more details are listed for this place.'
                  : display,
              phone: null,
            ),
          );
        }
      } catch (e) {
        debugPrint('[Places] nominatim failed: $e');
      }
    }
    return gotAnyResponse ? places : null;
  }

  List<SafetyMarker> _parse(List elements) {
    final seen = <String>{};
    final places = <SafetyMarker>[];

    for (final el in elements) {
      if (el is! Map) continue;
      final tags = (el['tags'] is Map)
          ? Map<String, dynamic>.from(el['tags'] as Map)
          : <String, dynamic>{};
      String? tag(String k) {
        final v = tags[k]?.toString().trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      // Nodes carry lat/lon; buildings (ways) carry a center point.
      double? lat;
      double? lng;
      if (el['lat'] is num && el['lon'] is num) {
        lat = (el['lat'] as num).toDouble();
        lng = (el['lon'] as num).toDouble();
      } else if (el['center'] is Map) {
        final c = el['center'] as Map;
        if (c['lat'] is num && c['lon'] is num) {
          lat = (c['lat'] as num).toDouble();
          lng = (c['lon'] as num).toDouble();
        }
      }
      if (lat == null || lng == null) continue;

      final amenity = tag('amenity');
      final String type;
      final String fallbackName;
      if (amenity == 'police') {
        type = 'police';
        fallbackName = 'Police station';
      } else if (amenity == 'hospital') {
        type = 'hospital';
        fallbackName = 'Hospital';
      } else if (amenity == 'social_facility') {
        type = 'shelter';
        fallbackName = "Women's support center";
      } else {
        continue;
      }

      final id = '${el['type']}-${el['id']}';
      if (!seen.add(id)) continue;

      final name = tag('name:en') ?? tag('name') ?? fallbackName;

      final address = [
        tag('addr:housenumber'),
        tag('addr:street'),
        tag('addr:suburb'),
        tag('addr:city'),
      ].whereType<String>().join(', ');

      final parts = <String>[];
      if (address.isNotEmpty) parts.add(address);
      if (type == 'hospital' && tag('emergency') == 'yes') {
        parts.add('Emergency department listed');
      }
      final hours = tag('opening_hours');
      if (hours != null) parts.add('Hours: $hours');
      final operator = tag('operator');
      if (operator != null) parts.add('Run by $operator');

      // Phone numbers may list several; keep the first.
      final rawPhone =
          tag('phone') ?? tag('contact:phone') ?? tag('contact:mobile');
      String? phone;
      if (rawPhone != null) {
        final first = rawPhone.split(RegExp(r'[;,/]')).first.trim();
        if (first.isNotEmpty) phone = first;
      }

      places.add(
        SafetyMarker(
          id: id,
          name: name,
          type: type,
          lat: lat,
          lng: lng,
          description: parts.isEmpty
              ? 'No more details are listed for this place.'
              : parts.join('\n'),
          phone: phone,
        ),
      );
    }
    return places;
  }
}
