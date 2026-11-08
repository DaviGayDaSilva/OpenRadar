import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../models/weather_alert.dart';
import 'api_client.dart';

/// Servico de alertas meteorologicos oficiais.
///
/// Fontes reais:
///  - INMET: avisos de perigo em vigor no Brasil (com poligono).
///  - NOAA/NWS: alertas ativos nos Estados Unidos (com poligono).
///  - CPTEC/INPE: avisos meteorologicos (quando disponiveis).
class AlertsService {
  AlertsService(this._api);

  final ApiClient _api;

  static const String _inmet = 'https://apiprevmet3.inmet.gov.br/avisos/ativos';
  static const String _nws = 'https://api.weather.gov/alerts/active';

  static const Duration ttl = Duration(minutes: 10);
  static const Duration tolerance = Duration(minutes: 45);
  static const String cacheKey = 'alerts_all';

  Future<FetchResult<List<WeatherAlert>>> fetchAll({bool force = false}) async {
    final cached = CacheStore.instance.get<List<dynamic>>(cacheKey);
    if (!force && cached != null && CacheStore.instance.isFresh(cacheKey)) {
      return FetchResult(
        data: cached.map((e) => _fromCache((e as Map).cast<String, dynamic>())).toList(),
        fetchedAt: CacheStore.instance.savedAt(cacheKey)!,
        fromCache: true,
      );
    }

    final results = await Future.wait([
      _fetchInmet(),
      _fetchNws(),
    ]);

    final alerts = <WeatherAlert>[...results[0], ...results[1]];
    final anySuccess = results[0].isNotEmpty || results[1].isNotEmpty;

    if (anySuccess) {
      await CacheStore.instance.put(cacheKey, alerts.map(_toCache).toList(), ttl);
      return FetchResult(data: alerts, fetchedAt: DateTime.now(), fromCache: false);
    }

    if (cached != null) {
      return FetchResult(
        data: cached.map((e) => _fromCache((e as Map).cast<String, dynamic>())).toList(),
        fetchedAt: CacheStore.instance.savedAt(cacheKey) ?? DateTime.now(),
        fromCache: true,
        error: 'Sem conexao com as fontes de alertas',
      );
    }
    return FetchResult(data: const [], fetchedAt: DateTime.now(), fromCache: false, error: 'Sem conexao');
  }

  Future<List<WeatherAlert>> _fetchInmet() async {
    try {
      final raw = await _api.getJson<Map<String, dynamic>>(_inmet, (j) => (j as Map).cast<String, dynamic>());
      final out = <WeatherAlert>[];
      for (final bucket in ['hoje', 'amanha']) {
        final list = raw[bucket] as List?;
        if (list == null) continue;
        for (final item in list) {
          final a = _inmetAlert((item as Map).cast<String, dynamic>());
          if (a != null) out.add(a);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  WeatherAlert? _inmetAlert(Map<String, dynamic> m) {
    try {
      final id = 'inmet_${m['id'] ?? m['id_aviso']}';
      final poligono = m['poligono'];
      final polygons = <List<LatLng>>[];
      if (poligono is String && poligono.isNotEmpty) {
        try {
          final geo = jsonDecode(poligono) as Map<String, dynamic>;
          final coords = geo['coordinates'] as List?;
          if (coords != null && coords.isNotEmpty) {
            final ring = (coords.first as List)
                .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
                .toList();
            if (ring.length >= 3) polygons.add(ring);
          }
        } catch (_) {}
      }

      DateTime? parse(String? date, String? hour) {
        if (date == null) return null;
        final d = date.split('T').first;
        final h = (hour ?? '00:00');
        return DateTime.tryParse('${d}T$h:00')?.toUtc();
      }

      final sev = _inmetSeverity(m['id_condicao_severa']);
      return WeatherAlert(
        id: id,
        title: (m['titulo'] as String?) ?? 'Aviso INMET',
        event: (m['descricao'] as String?)?.split('.').first ?? 'Aviso meteorologico',
        source: 'INMET',
        severity: sev,
        description: (m['descricao'] as String?) ?? '',
        instruction: (m['instrucoes'] as String?) ?? '',
        areaDesc: (m['riscos'] as String?) ?? '',
        onset: parse(m['data_inicio'] as String?, m['hora_inicio'] as String?),
        ends: parse(m['data_fim'] as String?, m['hora_fim'] as String?),
        polygons: polygons,
      );
    } catch (_) {
      return null;
    }
  }

  AlertSeverity _inmetSeverity(dynamic cond) {
    final c = cond is int ? cond : int.tryParse('$cond') ?? 0;
    if (c == 3) return AlertSeverity.extreme;
    if (c == 2) return AlertSeverity.severe;
    return AlertSeverity.moderate;
  }

  Future<List<WeatherAlert>> _fetchNws() async {
    try {
      final raw = await _api.getJson<Map<String, dynamic>>(
        '$_nws?status=actual&message_type=alert',
        (j) => (j as Map).cast<String, dynamic>(),
      );
      final features = raw['features'] as List? ?? const [];
      return features.map((f) {
        final props = (f['properties'] as Map).cast<String, dynamic>();
        final geom = f['geometry'];
        final polygons = <List<LatLng>>[];
        if (geom is Map && geom['coordinates'] is List) {
          final type = geom['type'] as String?;
          final coords = geom['coordinates'] as List;
          if (type == 'Polygon') {
            for (final ring in coords) {
              final pts = (ring as List)
                  .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
                  .toList();
              if (pts.length >= 3) polygons.add(pts);
            }
          } else if (type == 'MultiPolygon') {
            for (final poly in coords) {
              for (final ring in (poly as List)) {
                final pts = (ring as List)
                    .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
                    .toList();
                if (pts.length >= 3) polygons.add(pts);
              }
            }
          }
        }
        return WeatherAlert(
          id: (props['id'] as String?) ?? '',
          title: (props['headline'] as String?) ?? (props['event'] as String?) ?? 'Alerta NWS',
          event: (props['event'] as String?) ?? '',
          source: 'NOAA/NWS',
          severity: WeatherAlert.severityFromText(props['severity'] as String?),
          description: (props['description'] as String?) ?? '',
          instruction: (props['instruction'] as String?) ?? '',
          areaDesc: (props['areaDesc'] as String?) ?? '',
          onset: DateTime.tryParse('${props['onset'] ?? props['effective'] ?? ''}')?.toUtc(),
          ends: DateTime.tryParse('${props['ends'] ?? props['expires'] ?? ''}')?.toUtc(),
          sent: DateTime.tryParse('${props['sent'] ?? ''}')?.toUtc(),
          polygons: polygons,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _toCache(WeatherAlert a) => {
        'id': a.id,
        'title': a.title,
        'event': a.event,
        'source': a.source,
        'severity': a.severity.name,
        'description': a.description,
        'instruction': a.instruction,
        'areaDesc': a.areaDesc,
        'onset': a.onset?.toIso8601String(),
        'ends': a.ends?.toIso8601String(),
        'sent': a.sent?.toIso8601String(),
        'polygons': a.polygons.map((ring) => ring.map((p) => [p.longitude, p.latitude]).toList()).toList(),
      };

  WeatherAlert _fromCache(Map<String, dynamic> m) {
    final polys = (m['polygons'] as List? ?? const [])
        .map((ring) => (ring as List)
            .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
            .toList())
        .toList();
    return WeatherAlert(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      event: m['event'] as String? ?? '',
      source: m['source'] as String? ?? '',
      severity: AlertSeverity.values.firstWhere(
        (s) => s.name == m['severity'],
        orElse: () => AlertSeverity.unknown,
      ),
      description: m['description'] as String? ?? '',
      instruction: m['instruction'] as String? ?? '',
      areaDesc: m['areaDesc'] as String? ?? '',
      onset: DateTime.tryParse(m['onset'] as String? ?? '')?.toUtc(),
      ends: DateTime.tryParse(m['ends'] as String? ?? '')?.toUtc(),
      sent: DateTime.tryParse(m['sent'] as String? ?? '')?.toUtc(),
      polygons: polys,
    );
  }
}
