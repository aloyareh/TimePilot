import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/cafes/nearby_places_service.dart';

void main() {
  const lat = -7.7829, lon = 110.3671;

  test('jarak haversine: ~111 km per derajat lintang', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 300));
    expect(distanceMeters(lat, lon, lat, lon), 0);
  });

  test('format jarak', () {
    expect(formatDistance(350.4), '350 m');
    expect(formatDistance(1520), '1.5 km');
  });

  test('parsePlaces: urut terdekat, node dan way, tanpa nama dibuang, duplikat digabung', () {
    final json = {
      'elements': [
        {
          'type': 'node', 'id': 1, 'lat': lat + 0.009, 'lon': lon,
          'tags': {'name': 'Jauh', 'amenity': 'cafe'},
        },
        {
          'type': 'way', 'id': 2,
          'center': {'lat': lat + 0.001, 'lon': lon},
          'tags': {
            'name': 'Dekat', 'amenity': 'cafe', 'internet_access': 'wlan',
            'opening_hours': 'Mo-Su 08:00-22:00', 'addr:street': 'Jl. Kaliurang',
          },
        },
        {
          'type': 'node', 'id': 3, 'lat': lat + 0.004, 'lon': lon,
          'tags': {'name': 'Ruang Kerja', 'office': 'coworking'},
        },
        {'type': 'node', 'id': 4, 'lat': lat, 'lon': lon, 'tags': {'amenity': 'cafe'}},
        {
          'type': 'node', 'id': 5, 'lat': lat + 0.001, 'lon': lon,
          'tags': {'name': 'dekat', 'amenity': 'cafe'},
        },
        {'type': 'relation', 'id': 6, 'tags': {'name': 'Tanpa Koordinat'}},
      ],
    };
    final r = parsePlaces(json, lat, lon);
    expect(r.map((c) => c.name), ['Dekat', 'Ruang Kerja', 'Jauh']);
    expect(r[0].type, 'Kafe');
    expect(r[0].area, contains('Jl. Kaliurang'));
    expect(r[0].note, contains('WiFi'));
    expect(r[0].note, contains('08:00-22:00'));
    expect(r[1].type, 'Coworking');
    expect(r[2].area, contains('km'));
  });

  test('limit dan hasil kosong', () {
    expect(parsePlaces({'elements': []}, lat, lon), isEmpty);
    final many = {
      'elements': [
        for (var i = 0; i < 20; i++)
          {'type': 'node', 'id': i, 'lat': lat + i * 0.0005, 'lon': lon, 'tags': {'name': 'K$i'}},
      ],
    };
    expect(parsePlaces(many, lat, lon, limit: 5), hasLength(5));
  });

  test('respons rusak melempar FormatException', () {
    expect(() => parsePlaces({'x': 1}, lat, lon), throwsFormatException);
  });

  test('parseNominatim: kafe dan coworking, urut jarak, jenis lain dibuang', () {
    final items = [
      {'name': 'Jauh', 'lat': '${lat + 0.009}', 'lon': '$lon', 'type': 'cafe'},
      {
        'name': 'Dekat', 'lat': '${lat + 0.001}', 'lon': '$lon', 'type': 'cafe',
        'extratags': {'internet_access': 'wlan', 'opening_hours': '08:00-22:00'},
        'address': {'road': 'Jl. Kaliurang'},
      },
      {'name': 'Hub Kerja Cowork', 'lat': '${lat + 0.004}', 'lon': '$lon', 'type': 'office'},
      {'name': 'Toko', 'lat': '$lat', 'lon': '$lon', 'type': 'convenience'},
      {'name': '', 'lat': '$lat', 'lon': '$lon', 'type': 'cafe'},
    ];
    final r = parseNominatim(items, lat, lon);
    expect(r.map((c) => c.name), ['Dekat', 'Hub Kerja Cowork', 'Jauh']);
    expect(r[0].note, contains('WiFi'));
    expect(r[0].area, contains('Jl. Kaliurang'));
    expect(r[1].type, 'Coworking');
  });
}