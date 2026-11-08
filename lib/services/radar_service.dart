import '../models/radar_frame.dart';
import 'api_client.dart';

/// Servico do radar de chuva.
///
/// Fonte: RainViewer, que agrega mosaicos de radares reais e oferece
/// quadros passados (aprox. 2 h) e nowcast (aprox. 30 min).
class RadarService {
  RadarService(this._api);

  final ApiClient _api;
  static const String _url = 'https://api.rainviewer.com/public/weather-maps.json';

  /// O radar atualiza a cada ~10 minutos; a tolerancia reflete isso.
  static const Duration ttl = Duration(minutes: 5);
  static const Duration tolerance = Duration(minutes: 25);
  static const String cacheKey = 'radar_timeline';

  Future<FetchResult<RadarTimeline>> timeline({bool force = false}) async {
    final cached = CacheStore.instance.get<Map<String, dynamic>>(cacheKey);
    if (!force && cached != null && CacheStore.instance.isFresh(cacheKey)) {
      return FetchResult(
        data: RadarTimeline.fromJson(cached),
        fetchedAt: CacheStore.instance.savedAt(cacheKey)!,
        fromCache: true,
      );
    }
    try {
      final raw = await _api.getJson<Map<String, dynamic>>(_url, (j) => j as Map<String, dynamic>);
      await CacheStore.instance.put(cacheKey, raw, ttl);
      return FetchResult(data: RadarTimeline.fromJson(raw), fetchedAt: DateTime.now(), fromCache: false);
    } catch (e) {
      if (cached != null) {
        return FetchResult(
          data: RadarTimeline.fromJson(cached),
          fetchedAt: CacheStore.instance.savedAt(cacheKey) ?? DateTime.now(),
          fromCache: true,
          error: e.toString(),
        );
      }
      return FetchResult(data: null, fetchedAt: DateTime.now(), fromCache: false, error: e.toString());
    }
  }
}
