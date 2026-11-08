import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../models/weather_point.dart';
import 'api_client.dart';

/// Servico de dados meteorologicos pontuais e de grade.
///
/// Fonte principal: Open-Meteo (modelos ICON/GFS/ECMWF agregados, dados reais).
/// Fonte brasileira: CPTEC/INPE para previsao por municipio.
class WeatherService {
  WeatherService(this._api);

  final ApiClient _api;

  static const String _base = 'https://api.open-meteo.com/v1/forecast';
  static const String _cptecBase = 'https://servicos.cptec.inpe.br/XML';

  static const List<String> _currentFields = [
    'temperature_2m',
    'relative_humidity_2m',
    'apparent_temperature',
    'pressure_msl',
    'surface_pressure',
    'wind_speed_10m',
    'wind_direction_10m',
    'wind_gusts_10m',
    'cloud_cover',
    'precipitation',
    'precipitation_probability',
    'dew_point_2m',
    'cape',
    'lifted_index',
    'freezing_level_height',
    'visibility',
    'uv_index',
    'lightning_potential',
  ];

  static const Duration ttl = Duration(minutes: 10);
  static const Duration tolerance = Duration(minutes: 40);

  String _key(double lat, double lon) => 'wx_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';

  /// Condicoes atuais em um ponto.
  Future<FetchResult<WeatherPoint>> currentAt(LatLng p, {bool force = false}) async {
    final key = _key(p.latitude, p.longitude);
    final cached = CacheStore.instance.get<Map<String, dynamic>>(key);
    if (!force && cached != null && CacheStore.instance.isFresh(key)) {
      return FetchResult(
        data: WeatherPoint.fromOpenMeteo(cached),
        fetchedAt: CacheStore.instance.savedAt(key)!,
        fromCache: true,
      );
    }
    try {
      final url = '$_base?latitude=${p.latitude}&longitude=${p.longitude}'
          '&current=${_currentFields.join(',')}'
          '&daily=temperature_2m_min,temperature_2m_max,precipitation_probability_max'
          '&timezone=UTC&forecast_days=2';
      final raw = await _api.getJson<Map<String, dynamic>>(url, (j) => j as Map<String, dynamic>);
      await CacheStore.instance.put(key, raw, ttl);
      final point = WeatherPoint.fromOpenMeteo(raw);
      final enriched = _withDaily(raw, point);
      return FetchResult(data: enriched, fetchedAt: DateTime.now(), fromCache: false);
    } catch (e) {
      if (cached != null) {
        return FetchResult(
          data: _withDaily(cached, WeatherPoint.fromOpenMeteo(cached)),
          fetchedAt: CacheStore.instance.savedAt(key) ?? DateTime.now(),
          fromCache: true,
          error: e.toString(),
        );
      }
      return FetchResult(data: null, fetchedAt: DateTime.now(), fromCache: false, error: e.toString());
    }
  }

  WeatherPoint _withDaily(Map<String, dynamic> raw, WeatherPoint base) {
    final daily = raw['daily'] as Map<String, dynamic>?;
    if (daily == null) return base;
    final mins = (daily['temperature_2m_min'] as List?)?.whereType<num>().toList();
    final maxs = (daily['temperature_2m_max'] as List?)?.whereType<num>().toList();
    return WeatherPoint(
      lat: base.lat,
      lon: base.lon,
      time: base.time,
      temperature: base.temperature,
      apparentTemperature: base.apparentTemperature,
      temperatureMin: mins != null && mins.isNotEmpty ? mins.first.toDouble() : null,
      temperatureMax: maxs != null && maxs.isNotEmpty ? maxs.first.toDouble() : null,
      humidity: base.humidity,
      pressure: base.pressure,
      surfacePressure: base.surfacePressure,
      windSpeed: base.windSpeed,
      windDirection: base.windDirection,
      windGust: base.windGust,
      cloudCover: base.cloudCover,
      precipitation: base.precipitation,
      precipitationProbability: base.precipitationProbability,
      dewPoint: base.dewPoint,
      cape: base.cape,
      liftedIndex: base.liftedIndex,
      freezingLevel: base.freezingLevel,
      visibility: base.visibility,
      uvIndex: base.uvIndex,
      lightningPotential: base.lightningPotential,
      elevation: base.elevation,
    );
  }

  /// Amostra uma grade regular de pontos reais em torno do centro do mapa.
  /// Usado pelas camadas de temperatura, vento, umidade, pressao, nuvens,
  /// sensacao termica, granizo e tempestades.
  Future<FetchResult<List<WeatherPoint>>> grid({
    required LatLng center,
    required double latSpan,
    required double lonSpan,
    int rows = 13,
    int cols = 13,
    bool force = false,
  }) async {
    final latSpanClamped = latSpan.clamp(4.0, 60.0);
    final lonSpanClamped = lonSpan.clamp(4.0, 90.0);
    final key = 'grid_${center.latitude.toStringAsFixed(1)}_${center.longitude.toStringAsFixed(1)}'
        '_${latSpanClamped.toStringAsFixed(0)}_${lonSpanClamped.toStringAsFixed(0)}_${rows}x$cols';

    final cached = CacheStore.instance.get<List<dynamic>>(key);
    if (!force && cached != null && CacheStore.instance.isFresh(key)) {
      return FetchResult(
        data: cached.map((e) => WeatherPoint.fromOpenMeteo((e as Map).cast<String, dynamic>())).toList(),
        fetchedAt: CacheStore.instance.savedAt(key)!,
        fromCache: true,
      );
    }

    final lats = <double>[];
    final lons = <double>[];
    final latStep = latSpanClamped / (rows - 1);
    final lonStep = lonSpanClamped / (cols - 1);
    for (var i = 0; i < rows; i++) {
      final lat = (center.latitude - latSpanClamped / 2 + i * latStep).clamp(-85.0, 85.0);
      for (var j = 0; j < cols; j++) {
        var lon = center.longitude - lonSpanClamped / 2 + j * lonStep;
        if (lon > 180) lon -= 360;
        if (lon < -180) lon += 360;
        lats.add(double.parse(lat.toStringAsFixed(4)));
        lons.add(double.parse(lon.toStringAsFixed(4)));
      }
    }

    try {
      final url = '$_base?latitude=${lats.join(',')}&longitude=${lons.join(',')}'
          '&current=${_currentFields.join(',')}&timezone=UTC';
      final raw = await _api.getJson<List<dynamic>>(url, (j) => j as List<dynamic>);
      final maps = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
      await CacheStore.instance.put(key, maps, ttl);
      return FetchResult(
        data: maps.map(WeatherPoint.fromOpenMeteo).toList(),
        fetchedAt: DateTime.now(),
        fromCache: false,
      );
    } catch (e) {
      if (cached != null) {
        return FetchResult(
          data: cached.map((e) => WeatherPoint.fromOpenMeteo((e as Map).cast<String, dynamic>())).toList(),
          fetchedAt: CacheStore.instance.savedAt(key) ?? DateTime.now(),
          fromCache: true,
          error: e.toString(),
        );
      }
      return FetchResult(data: null, fetchedAt: DateTime.now(), fromCache: false, error: e.toString());
    }
  }

  /// Previsao diaria do CPTEC/INPE para um municipio brasileiro.
  /// Retorna lista vazia quando nao ha dados (municipio fora da cobertura).
  Future<List<DailyForecast>> cptecForecast(int cityId) async {
    final key = 'cptec_$cityId';
    final cached = CacheStore.instance.get<String>(key);
    if (cached != null && CacheStore.instance.isFresh(key)) {
      return _parseCptec(cached);
    }
    try {
      final xml = await _api.getText(
        '$_cptecBase/cidade/$cityId/previsao.xml',
        encoding: latin1,
      );
      await CacheStore.instance.put(key, xml, const Duration(hours: 3));
      return _parseCptec(xml);
    } catch (_) {
      return cached != null ? _parseCptec(cached) : const [];
    }
  }

  /// Codigos de tempo do CPTEC/INPE traduzidos para texto.
  static const Map<String, String> cptecConditions = {
    'ec': 'Encoberto com chuvas isoladas',
    'ci': 'Chuvas isoladas',
    'c': 'Chuvas',
    'in': 'Instavel',
    'pp': 'Possibilidade de pancadas de chuva',
    'cm': 'Chuvas pela manha',
    'cn': 'Chuvas pela noite',
    'cl': 'Ceu claro',
    'n': 'Nublado',
    'nv': 'Nublado com ventos',
    'pc': 'Parcialmente nublado',
    'pn': 'Parcialmente nublado',
    'nm': 'Nublado pela manha',
    'nn': 'Nublado pela noite',
    'mn': 'Muitas nuvens',
    'sc': 'Sol com muitas nuvens',
    'vc': 'Variavel com chuvas',
    'vs': 'Variavel com sol',
    'ch': 'Chuvoso',
  };

  List<DailyForecast> _parseCptec(String xml) {
    final out = <DailyForecast>[];
    try {
      final doc = XmlDocument.parse(xml);
      for (final node in doc.findAllElements('previsao')) {
        final dia = node.findElements('dia').firstOrNull?.innerText;
        final max = node.findElements('maxima').firstOrNull?.innerText;
        final min = node.findElements('minima').firstOrNull?.innerText;
        final tempo = node.findElements('tempo').firstOrNull?.innerText;
        if (dia == null) continue;
        out.add(DailyForecast(
          date: DateTime.tryParse(dia) ?? DateTime.now(),
          min: double.tryParse(min ?? ''),
          max: double.tryParse(max ?? ''),
          condition: tempo == null ? null : (cptecConditions[tempo.trim().toLowerCase()] ?? tempo),
          source: 'CPTEC/INPE',
        ));
      }
    } catch (_) {}
    return out;
  }

  /// Busca municipios brasileiros no CPTEC para localizar o ID da cidade.
  Future<List<CptecCity>> searchCity(String name) async {
    try {
      final xml = await _api.getText(
        '$_cptecBase/listaCidades?city=${Uri.encodeComponent(name)}',
        retries: 1,
        encoding: latin1,
      );
      final doc = XmlDocument.parse(xml);
      return doc.findAllElements('cidade').map((n) {
        return CptecCity(
          id: int.tryParse(n.findElements('id').firstOrNull?.innerText ?? '') ?? 0,
          nome: n.findElements('nome').firstOrNull?.innerText ?? '',
          uf: n.findElements('uf').firstOrNull?.innerText ?? '',
        );
      }).where((c) => c.id > 0).toList();
    } catch (_) {
      return const [];
    }
  }
}

class CptecCity {
  const CptecCity({required this.id, required this.nome, required this.uf});
  final int id;
  final String nome;
  final String uf;
}
