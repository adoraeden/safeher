import 'dart:convert';

import 'package:http/http.dart' as http;

class PlaceResult {
  final String title;
  final String subtitle;
  final double lat;
  final double lng;

  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  String get fullName => subtitle.isEmpty ? title : '$title, $subtitle';
}

/// Place suggestions while typing, from the free Photon service.
class PlaceSearchService {
  static const _headers = {
    'User-Agent': 'com.safeher.women_safety (college project)',
  };

  Future<List<PlaceResult>> search(
    String query, {
    double? nearLat,
    double? nearLng,
    int limit = 6,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final params = <String, String>{'q': q, 'limit': '$limit', 'lang': 'en'};
    if (nearLat != null && nearLng != null) {
      params['lat'] = '$nearLat';
      params['lon'] = '$nearLng';
    }

    Map<String, dynamic>? data;
    try {
      final response = await http
          .get(Uri.https('photon.komoot.io', '/api/', params), headers: _headers)
          .timeout(const Duration(milliseconds: 3500));
      if (response.statusCode == 200) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Photon call failed, will try fallback below
    }

    if (data == null) {
      final fallback = await _searchNominatim(q, limit: limit);
      if (fallback.isNotEmpty) return fallback;
      throw Exception('Place search is unavailable right now.');
    }

    final features = (data['features'] as List?) ?? const [];
    final seen = <String>{};
    final results = <PlaceResult>[];

    for (final f in features) {
      if (f is! Map) continue;
      final coords = (f['geometry'] is Map)
          ? f['geometry']['coordinates']
          : null;
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      final props = (f['properties'] is Map)
          ? Map<String, dynamic>.from(f['properties'] as Map)
          : <String, dynamic>{};
      String? s(String key) {
        final v = props[key]?.toString().trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      final name = s('name');
      final street = s('street');
      final house = s('housenumber');
      final streetLine = street == null
          ? null
          : (house == null ? street : '$house $street');
      final city = s('city') ?? s('locality');

      final title =
          name ??
          streetLine ??
          s('district') ??
          city ??
          s('state') ??
          s('country') ??
          'Unnamed place';

      final parts = <String>[];
      void add(String? v) {
        if (v != null && v != title && !parts.contains(v)) parts.add(v);
      }

      if (name != null) add(streetLine);
      add(s('district'));
      add(city);
      add(s('state'));
      add(s('country'));
      final subtitle = parts.join(', ');

      if (!seen.add('$title|$subtitle')) continue;
      results.add(
        PlaceResult(title: title, subtitle: subtitle, lat: lat, lng: lng),
      );
    }
    return results;
  }

  Future<List<PlaceResult>> _searchNominatim(
    String query, {
    int limit = 6,
  }) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=$limit&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List;
      final results = <PlaceResult>[];
      for (final item in list) {
        if (item is! Map) continue;
        final name = (item['name'] ?? item['display_name'] ?? '').toString();
        final displayName = (item['display_name'] ?? '').toString();
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;
        final title =
            name.isNotEmpty ? name : displayName.split(',').first.trim();
        final subtitle = displayName != title ? displayName : '';
        results.add(
          PlaceResult(title: title, subtitle: subtitle, lat: lat, lng: lon),
        );
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
