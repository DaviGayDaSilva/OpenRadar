import '../models/tornado_event.dart';
import 'api_client.dart';

/// Servico de monitoramento de tornados.
///
/// IMPORTANTE: o OpenRadar NAO inventa ocorrencias. Toda entrada vem de:
///  - NOAA/NWS Storm-Based Warnings: avisos de tornado em vigor (oficiais).
///  - NOAA/SPC Storm Reports: relatorios de tornado confirmado no solo,
///    com hora, local, estado e escala Fujita/EF quando informada.
///
/// O Brasil nao publica um catalogo publico aberto equivalente em tempo real;
/// quando nao ha fonte, o app informa explicitamente a indisponibilidade.
class TornadoService {
  TornadoService(this._api);

  final ApiClient _api;

  static const String _spcToday = 'https://www.spc.noaa.gov/climo/reports/today_torn.csv';
  static const String _spcLast3h = 'https://www.spc.noaa.gov/climo/reports/last3hours_torn.csv';
  static const String _nwsWarnings =
      'https://api.weather.gov/alerts/active?event=Tornado%20Warning&status=actual&message_type=alert';

  static const Duration ttl = Duration(minutes: 5);
  static const Duration tolerance = Duration(minutes: 30);
  static const String cacheKey = 'tornado_events';

  /// Estados americanos por sigla, usados apenas para exibicao legivel.
  static const Map<String, String> _stateNames = {
    'AL': 'Alabama', 'AK': 'Alasca', 'AZ': 'Arizona', 'AR': 'Arkansas', 'CA': 'California',
    'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware', 'FL': 'Florida', 'GA': 'Georgia',
    'HI': 'Hawaii', 'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
    'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
    'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
    'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada', 'NH': 'New Hampshire',
    'NJ': 'New Jersey', 'NM': 'Novo Mexico', 'NY': 'Nova York', 'NC': 'Carolina do Norte',
    'ND': 'Dakota do Norte', 'OH': 'Ohio', 'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pensilvania',
    'RI': 'Rhode Island', 'SC': 'Carolina do Sul', 'SD': 'Dakota do Sul', 'TN': 'Tennessee',
    'TX': 'Texas', 'UT': 'Utah', 'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington',
    'WV': 'Virginia Ocidental', 'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'Distrito de Columbia',
  };

  static String stateName(String sigla) => _stateNames[sigla.toUpperCase()] ?? sigla;

  Future<FetchResult<List<TornadoEvent>>> fetchAll({bool force = false}) async {
    final cached = CacheStore.instance.get<List<dynamic>>(cacheKey);
    if (!force && cached != null && CacheStore.instance.isFresh(cacheKey)) {
      return FetchResult(
        data: cached.map((e) => _fromCache((e as Map).cast<String, dynamic>())).toList(),
        fetchedAt: CacheStore.instance.savedAt(cacheKey)!,
        fromCache: true,
      );
    }

    final warnings = await _fetchWarnings();
    final reports = await _fetchReports();

    final events = <TornadoEvent>[...warnings, ...reports];
    if (warnings.isNotEmpty || reports.isNotEmpty) {
      await CacheStore.instance.put(cacheKey, events.map(_toCache).toList(), ttl);
      return FetchResult(data: events, fetchedAt: DateTime.now(), fromCache: false);
    }
    if (cached != null) {
      return FetchResult(
        data: cached.map((e) => _fromCache((e as Map).cast<String, dynamic>())).toList(),
        fetchedAt: CacheStore.instance.savedAt(cacheKey) ?? DateTime.now(),
        fromCache: true,
        error: 'Sem conexao com as fontes de tornados',
      );
    }
    return FetchResult(data: const [], fetchedAt: DateTime.now(), fromCache: false, error: 'Sem conexao');
  }

  Future<List<TornadoEvent>> _fetchWarnings() async {
    try {
      final raw = await _api.getJson<Map<String, dynamic>>(
        _nwsWarnings,
        (j) => (j as Map).cast<String, dynamic>(),
      );
      final features = raw['features'] as List? ?? const [];
      final out = <TornadoEvent>[];
      for (final f in features) {
        final props = (f['properties'] as Map).cast<String, dynamic>();
        final geom = f['geometry'];
        double? lat;
        double? lon;
        if (geom is Map && geom['coordinates'] is List) {
          final coords = geom['coordinates'] as List;
          final ring = (geom['type'] == 'Polygon')
              ? (coords.isNotEmpty ? coords.first as List : const [])
              : (coords.isNotEmpty ? ((coords.first as List).isNotEmpty ? (coords.first as List).first as List : const []) : const []);
          if (ring.isNotEmpty) {
            final pts = ring.map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]).toList();
            lon = pts.map((p) => p[0]).reduce((a, b) => a + b) / pts.length;
            lat = pts.map((p) => p[1]).reduce((a, b) => a + b) / pts.length;
          }
        }
        if (lat == null || lon == null) continue;
        out.add(TornadoEvent(
          status: TornadoStatus.warning,
          source: 'NOAA/NWS',
          lat: lat,
          lon: lon,
          time: DateTime.tryParse('${props['onset'] ?? props['sent'] ?? ''}')?.toUtc(),
          expires: DateTime.tryParse('${props['ends'] ?? props['expires'] ?? ''}')?.toUtc(),
          areaDesc: (props['areaDesc'] as String?) ?? '',
          comments: (props['headline'] as String?) ?? '',
          eventId: (props['id'] as String?) ?? '',
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<TornadoEvent>> _fetchReports() async {
    final out = <TornadoEvent>[];
    for (final url in [_spcLast3h, _spcToday]) {
      try {
        final csv = await _api.getText(url, retries: 1);
        out.addAll(_parseSpcCsv(csv, url == _spcLast3h ? 'ultimas 3 h' : 'hoje'));
      } catch (_) {}
    }
    // Deduplica relatorios repetidos entre os arquivos.
    final seen = <String>{};
    final dedup = <TornadoEvent>[];
    for (final e in out) {
      final k = '${e.time?.toIso8601String()}_${e.lat.toStringAsFixed(3)}_${e.lon.toStringAsFixed(3)}_${e.location}';
      if (seen.add(k)) dedup.add(e);
    }
    dedup.sort((a, b) => (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)));
    return dedup;
  }

  List<TornadoEvent> _parseSpcCsv(String csv, String window) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final out = <TornadoEvent>[];
    final now = DateTime.now().toUtc();
    for (var i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < 7) continue;
      final time = cols[0].trim();
      final fscale = cols[1].trim();
      final location = cols[2].trim();
      final county = cols[3].trim();
      final state = cols[4].trim();
      final lat = double.tryParse(cols[5].trim());
      final lon = double.tryParse(cols[6].trim());
      final comments = cols.length > 7 ? cols.sublist(7).join(',').trim() : '';
      if (lat == null || lon == null) continue;
      // SPC usa hora UTC no formato HHMM.
      DateTime? when;
      if (time.length == 4) {
        final hh = int.tryParse(time.substring(0, 2));
        final mm = int.tryParse(time.substring(2, 4));
        if (hh != null && mm != null) {
          when = DateTime.utc(now.year, now.month, now.day, hh, mm);
          if (when.isAfter(now.add(const Duration(minutes: 5)))) {
            when = when.subtract(const Duration(days: 1));
          }
        }
      }
      out.add(TornadoEvent(
        status: TornadoStatus.confirmed,
        source: 'NOAA/SPC ($window)',
        lat: lat,
        lon: lon,
        time: when,
        fScale: fscale.isEmpty || fscale.toUpperCase() == 'UNK' ? null : fscale,
        location: location,
        county: county,
        state: state,
        comments: comments,
      ));
    }
    return out;
  }

  Map<String, dynamic> _toCache(TornadoEvent e) => {
        'status': e.status.name,
        'source': e.source,
        'lat': e.lat,
        'lon': e.lon,
        'time': e.time?.toIso8601String(),
        'fScale': e.fScale,
        'location': e.location,
        'county': e.county,
        'state': e.state,
        'comments': e.comments,
        'areaDesc': e.areaDesc,
        'expires': e.expires?.toIso8601String(),
        'eventId': e.eventId,
      };

  TornadoEvent _fromCache(Map<String, dynamic> m) => TornadoEvent(
        status: TornadoStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => TornadoStatus.confirmed,
        ),
        source: m['source'] as String? ?? '',
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        time: DateTime.tryParse(m['time'] as String? ?? '')?.toUtc(),
        fScale: m['fScale'] as String?,
        location: m['location'] as String? ?? '',
        county: m['county'] as String? ?? '',
        state: m['state'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        areaDesc: m['areaDesc'] as String? ?? '',
        expires: DateTime.tryParse(m['expires'] as String? ?? '')?.toUtc(),
        eventId: m['eventId'] as String? ?? '',
      );
}
