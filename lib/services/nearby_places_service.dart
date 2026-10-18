import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/safety_marker.dart';

/// Finds real police stations, hospitals and women's support centers near a
/// point, from OpenStreetMap data (via the free Overpass service).
class NearbyPlacesService {
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const _headers = {
    'User-Agent': 'com.safeher.women_safety (college project)',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  static const _radiusMeters = 6000;
  static const _shelterRadiusMeters = 12000;
  static const _cacheMinutes = 10;

  // Remember the last result so moving around the map does not ask again.
  static String? _cacheKey;
  static DateTime? _cacheTime;
  static List<SafetyMarker> _cacheData = [];

  Future<List<SafetyMarker>> fetchNearby(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_cacheKey == key &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < _cacheMinutes) {
      return _cacheData;
    }

    final query =
        '''
[out:json][timeout:25];
(nwr["amenity"="police"](around:$_radiusMeters,$lat,$lng););
out center 40;
(nwr["amenity"="hospital"](around:$_radiusMeters,$lat,$lng););
out center 40;
(nwr["amenity"="social_facility"]["social_facility:for"~"woman|women",i](around:$_shelterRadiusMeters,$lat,$lng););
out center 30;
''';

    for (final endpoint in _endpoints) {
      try {
        final response = await http
            .post(Uri.parse(endpoint), headers: _headers, body: {'data': query})
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = _parse((data['elements'] as List?) ?? const []);
        _cacheKey = key;
        _cacheTime = DateTime.now();
        _cacheData = places;
        return places;
      } catch (_) {
        // This server failed, so try the next one.
      }
    }
    throw Exception(
      'Could not load nearby places right now. Check your internet connection and try again.',
    );
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
