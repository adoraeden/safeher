import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/safety_marker.dart';

/// Finds nearby police stations, hospitals and women's support centers
/// using OpenStreetMap data through the Overpass API.
class NearbyPlacesService {
  static const _endpoints = [
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  static const _headers = {
    'User-Agent': 'com.safeher.women_safety (college project)',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  static const _radiusMeters = 6000;
  static const _shelterRadiusMeters = 12000;
  static const _cacheMinutes = 10;

  // Cache the last result to reduce repeated requests.
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

    String lastFailure =
        'OpenStreetMap data services are temporarily unavailable.';

    for (final endpoint in _endpoints) {
      try {
        final response = await http
            .post(Uri.parse(endpoint), headers: _headers, body: {'data': query})
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 429) {
          lastFailure =
              'The map data service is busy. Please try again shortly.';
          continue;
        }

        if (response.statusCode != 200) {
          lastFailure =
              'Map data service returned HTTP ${response.statusCode}.';
          continue;
        }

        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
          lastFailure = 'The map data service returned an unexpected response.';
          continue;
        }

        final places = _parse(decoded['elements'] as List);

        _cacheKey = key;
        _cacheTime = DateTime.now();
        _cacheData = places;

        return places;
      } on TimeoutException {
        lastFailure =
            'Nearby places request timed out. The map service may be busy.';
      } on FormatException {
        lastFailure = 'The map data service returned an invalid response.';
      } catch (e) {
        lastFailure =
            'Could not contact the map data service (${e.runtimeType}).';
      }
    }

    throw Exception(lastFailure);
  }

  List<SafetyMarker> _parse(List elements) {
    final seen = <String>{};
    final places = <SafetyMarker>[];

    for (final el in elements) {
      if (el is! Map) continue;

      final tags = el['tags'] is Map
          ? Map<String, dynamic>.from(el['tags'] as Map)
          : <String, dynamic>{};

      String? tag(String key) {
        final value = tags[key]?.toString().trim();
        return value == null || value.isEmpty ? null : value;
      }

      // Nodes have lat/lon. Ways and relations may have a center point.
      double? placeLat;
      double? placeLng;

      if (el['lat'] is num && el['lon'] is num) {
        placeLat = (el['lat'] as num).toDouble();
        placeLng = (el['lon'] as num).toDouble();
      } else if (el['center'] is Map) {
        final center = el['center'] as Map;

        if (center['lat'] is num && center['lon'] is num) {
          placeLat = (center['lat'] as num).toDouble();
          placeLng = (center['lon'] as num).toDouble();
        }
      }

      if (placeLat == null || placeLng == null) continue;

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

      if (address.isNotEmpty) {
        parts.add(address);
      }

      if (type == 'hospital' && tag('emergency') == 'yes') {
        parts.add('Emergency department listed');
      }

      final hours = tag('opening_hours');
      if (hours != null) {
        parts.add('Hours: $hours');
      }

      final operator = tag('operator');
      if (operator != null) {
        parts.add('Run by $operator');
      }

      // Keep the first phone number if several are listed.
      final rawPhone =
          tag('phone') ?? tag('contact:phone') ?? tag('contact:mobile');

      String? phone;

      if (rawPhone != null) {
        final first = rawPhone.split(RegExp(r'[;,/]')).first.trim();
        if (first.isNotEmpty) {
          phone = first;
        }
      }

      places.add(
        SafetyMarker(
          id: id,
          name: name,
          type: type,
          lat: placeLat,
          lng: placeLng,
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
