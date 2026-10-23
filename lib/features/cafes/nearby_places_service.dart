import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'cafe_llm_service.dart';

/// Tempat kerja nyata di sekitar koordinat, dari OpenStreetMap lewat Overpass API
/// (gratis, tanpa kunci). Data bergantung pada kontribusi pengguna OSM, jadi
/// kafe yang belum dipetakan tidak muncul dan jam buka bisa kedaluwarsa.
class NearbyPlacesService {
  NearbyPlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static String buildQuery(double lat, double lon, int radiusMeters) => '''
[out:json][timeout:10];
(
  nwr["amenity"="cafe"]["name"](around:$radiusMeters,$lat,$lon);
  nwr["amenity"="coworking_space"]["name"](around:$radiusMeters,$lat,$lon);
  nwr["office"="coworking"]["name"](around:$radiusMeters,$lat,$lon);
);
out center 60;
''';

  Future<List<Cafe>> search({
    required double latitude,
    required double longitude,
    int radiusMeters = 1500,
    int limit = 8,
  }) async {
    final errors = <String>[];
    for (final url in _endpoints) {
      final host = Uri.parse(url).host;
      try {
        final res = await _client
            .post(
              Uri.parse(url),
              headers: {
                'User-Agent': 'TimePilot/0.1 (student project)',
                'Accept': 'application/json',
              },
              body: {'data': buildQuery(latitude, longitude, radiusMeters)},
            )
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) {
          errors.add('$host: HTTP ${res.statusCode}');
          continue;
        }
        return parsePlaces(
          jsonDecode(utf8.decode(res.bodyBytes)),
          latitude,
          longitude,
          limit: limit,
        );
      } catch (e) {
        errors.add('$host: ${e.runtimeType}');
      }
    }

    // Overpass publik sering penuh. Cadangan: Nominatim (juga data OSM, lebih ringan).
    try {
      return await _searchNominatim(latitude, longitude, radiusMeters, limit);
    } catch (e) {
      errors.add('nominatim: ${e is StateError ? e.message : e.runtimeType}');
    }
    throw StateError('Server peta tidak menjawab (${errors.join('; ')}).');
  }

  Future<List<Cafe>> _searchNominatim(
    double lat,
    double lon,
    int radiusMeters,
    int limit,
  ) async {
    final dLat = radiusMeters / 111320;
    final dLon = radiusMeters / (111320 * cos(lat * pi / 180));
    final viewbox = '${lon - dLon},${lat + dLat},${lon + dLon},${lat - dLat}';
    final all = <dynamic>[];
    for (final q in const ['cafe', 'coworking space']) {
      final res = await _client
          .get(
            Uri.https('nominatim.openstreetmap.org', '/search', {
              'q': q,
              'format': 'jsonv2',
              'viewbox': viewbox,
              'bounded': '1',
              'limit': '30',
              'extratags': '1',
              'namedetails': '1',
              'addressdetails': '1',
            }),
            headers: {
              'User-Agent': 'TimePilot/0.1 (student project)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is List) all.addAll(body);
    }
    return parseNominatim(all, lat, lon, limit: limit);
  }
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}

String formatDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// Mengubah respons Overpass menjadi daftar tempat, terdekat dulu. Fungsi murni.
List<Cafe> parsePlaces(
  dynamic json,
  double userLat,
  double userLon, {
  int limit = 8,
}) {
  final elements = json is Map ? json['elements'] : null;
  if (elements is! List) {
    throw const FormatException('Respons peta tidak sesuai.');
  }
  final found = <({Cafe cafe, double dist})>[];
  final seen = <String>{};
  for (final e in elements) {
    if (e is! Map) continue;
    final tags = e['tags'];
    if (tags is! Map) continue;
    final name = (tags['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final center = e['center'];
    final lat = ((e['lat'] ?? (center is Map ? center['lat'] : null)) as num?)
        ?.toDouble();
    final lon = ((e['lon'] ?? (center is Map ? center['lon'] : null)) as num?)
        ?.toDouble();
    if (lat == null || lon == null) continue;
    // Satu tempat bisa muncul sebagai node dan way sekaligus.
    if (!seen.add('${name.toLowerCase()}|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}')) {
      continue;
    }

    final cowork =
        tags['amenity'] == 'coworking_space' || tags['office'] == 'coworking';
    final dist = distanceMeters(userLat, userLon, lat, lon);
    final street = (tags['addr:street'] ?? '').toString().trim();
    final wifi = (tags['internet_access'] ?? '').toString();
    final hours = (tags['opening_hours'] ?? '').toString().trim();
    final notes = <String>[
      if (wifi == 'wlan' || wifi == 'yes') 'WiFi tersedia',
      if (hours.isNotEmpty) 'Jam buka: $hours',
    ];
    found.add((
      dist: dist,
      cafe: Cafe(
        name: name,
        type: cowork ? 'Coworking' : 'Kafe',
        area: [formatDistance(dist), if (street.isNotEmpty) street].join(' • '),
        note: notes.join(' · '),
        latitude: lat,
        longitude: lon,
      ),
    ));
  }
  found.sort((a, b) => a.dist.compareTo(b.dist));
  return found.take(limit).map((f) => f.cafe).toList();
}

/// Mengubah hasil Nominatim (jsonv2 + extratags + addressdetails) menjadi daftar
/// tempat, terdekat dulu. Fungsi murni.
List<Cafe> parseNominatim(
  List<dynamic> items,
  double userLat,
  double userLon, {
  int limit = 8,
}) {
  final found = <({Cafe cafe, double dist})>[];
  final seen = <String>{};
  for (final e in items) {
    if (e is! Map) continue;
    final name = (e['name'] ?? '').toString().trim();
    final lat = double.tryParse('${e['lat']}');
    final lon = double.tryParse('${e['lon']}');
    if (name.isEmpty || lat == null || lon == null) continue;
    if (!seen.add('${name.toLowerCase()}|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}')) {
      continue;
    }
    final type = (e['type'] ?? '').toString();
    final cowork = type.contains('cowork') || name.toLowerCase().contains('cowork');
    final isCafe = type == 'cafe' || type == 'coffee_shop';
    if (!cowork && !isCafe) continue;
    final extra = e['extratags'] is Map ? e['extratags'] as Map : const {};
    final addr = e['address'] is Map ? e['address'] as Map : const {};
    final street = (addr['road'] ?? '').toString().trim();
    final wifi = (extra['internet_access'] ?? '').toString();
    final hours = (extra['opening_hours'] ?? '').toString().trim();
    final dist = distanceMeters(userLat, userLon, lat, lon);
    found.add((
      dist: dist,
      cafe: Cafe(
        name: name,
        type: cowork ? 'Coworking' : 'Kafe',
        area: [formatDistance(dist), if (street.isNotEmpty) street].join(' • '),
        note: [
          if (wifi == 'wlan' || wifi == 'yes') 'WiFi tersedia',
          if (hours.isNotEmpty) 'Jam buka: $hours',
        ].join(' · '),
        latitude: lat,
        longitude: lon,
      ),
    ));
  }
  found.sort((a, b) => a.dist.compareTo(b.dist));
  return found.take(limit).map((f) => f.cafe).toList();
}