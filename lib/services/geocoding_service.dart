import 'package:latlong2/latlong.dart';

import 'api_client.dart';

/// Localidade retornada pela busca de cidades (Open-Meteo Geocoding).
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.country = '',
    this.admin1 = '',
    this.population = 0,
  });

  final String name;
  final double lat;
  final double lon;
  final String country;
  final String admin1;
  final int population;

  LatLng get position => LatLng(lat, lon);

  String get label {
    final parts = <String>[name];
    if (admin1.isNotEmpty) parts.add(admin1);
    if (country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}

/// Busca de cidades e localidades reais.
/// Fonte: Open-Meteo Geocoding (dados GeoNames).
class GeocodingService {
  GeocodingService(this._api);

  final ApiClient _api;
  static const String _url = 'https://geocoding-api.open-meteo.com/v1/search';

  final Map<String, List<GeoPlace>> _cache = {};

  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final key = q.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final raw = await _api.getJson<Map<String, dynamic>>(
        '$_url?name=${Uri.encodeComponent(q)}&count=8&language=pt&format=json',
        (j) => (j as Map).cast<String, dynamic>(),
        retries: 1,
      );
      final results = (raw['results'] as List? ?? const []);
      final places = results.map((r) {
        final m = (r as Map).cast<String, dynamic>();
        return GeoPlace(
          name: (m['name'] as String?) ?? '',
          lat: (m['latitude'] as num).toDouble(),
          lon: (m['longitude'] as num).toDouble(),
          country: (m['country'] as String?) ?? '',
          admin1: (m['admin1'] as String?) ?? '',
          population: (m['population'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      _cache[key] = places;
      return places;
    } catch (_) {
      return const [];
    }
  }
}
