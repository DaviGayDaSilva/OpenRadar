import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/formatters.dart';
import '../models/lightning_strike.dart';
import '../models/radar_frame.dart';
import '../models/tornado_event.dart';
import '../models/weather_alert.dart';
import '../models/weather_layer.dart';
import '../models/weather_point.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../services/geocoding_service.dart';
import '../services/lightning_service.dart';
import '../services/radar_service.dart';
import '../services/tornado_service.dart';
import '../services/weather_service.dart';

/// Estado de atualizacao de uma camada: quando foi atualizada, se veio do
/// cache, se esta carregando e qual o erro (se houver).
class LayerStatus {
  const LayerStatus({
    this.lastUpdate,
    this.loading = false,
    this.fromCache = false,
    this.error,
    this.live = false,
  });

  final DateTime? lastUpdate;
  final bool loading;
  final bool fromCache;
  final String? error;

  /// Verdadeiro quando a fonte entrega dados continuamente (tempo real).
  final bool live;

  LayerStatus copyWith({
    DateTime? lastUpdate,
    bool? loading,
    bool? fromCache,
    String? error,
    bool? live,
    bool clearError = false,
  }) =>
      LayerStatus(
        lastUpdate: lastUpdate ?? this.lastUpdate,
        loading: loading ?? this.loading,
        fromCache: fromCache ?? this.fromCache,
        error: clearError ? null : (error ?? this.error),
        live: live ?? this.live,
      );
}

/// Controlador central do OpenRadar. Concentra o estado do mapa, das camadas,
/// da linha do tempo e das atualizacoes periodicas.
class WeatherController extends ChangeNotifier {
  WeatherController({
    ApiClient? api,
    WeatherService? weather,
    RadarService? radar,
    AlertsService? alerts,
    TornadoService? tornado,
    LightningService? lightning,
    GeocodingService? geocoding,
  })  : api = api ?? ApiClient(),
        weather = weather ?? WeatherService(api ?? ApiClient()),
        radar = radar ?? RadarService(api ?? ApiClient()),
        alerts = alerts ?? AlertsService(api ?? ApiClient()),
        tornado = tornado ?? TornadoService(api ?? ApiClient()),
        lightning = lightning ?? LightningService(),
        geocoding = geocoding ?? GeocodingService(api ?? ApiClient());

  final ApiClient api;
  final WeatherService weather;
  final RadarService radar;
  final AlertsService alerts;
  final TornadoService tornado;
  final LightningService lightning;
  final GeocodingService geocoding;

  // ---------------------------------------------------------------- estado
  LatLng center = const LatLng(-14.24, -51.93); // Brasil por padrao
  double zoom = 4.2;

  LatLng? userLocation;
  bool locating = false;
  String? locationError;

  final Map<LayerId, double> activeLayers = {
    LayerId.rainRadar: 0.78,
    LayerId.lightning: 0.95,
    LayerId.alerts: 0.6,
  };

  final Map<LayerId, LayerStatus> status = {};

  WeatherPoint? focusPoint;
  String? focusPlaceName;
  List<DailyForecast> cptecDaily = const [];
  List<WeatherPoint> gridPoints = const [];
  int gridRows = 13;
  int gridCols = 13;
  LatLngBounds? gridBounds;
  List<WeatherAlert> alertsList = const [];
  List<TornadoEvent> tornadoEvents = const [];
  List<LightningStrike> strikes = const [];

  RadarTimeline? radarTimeline;
  int frameIndex = 0;
  bool playing = false;
  bool liveMode = true;

  Timer? _playTimer;
  Timer? _refreshTimer;
  StreamSubscription<List<LightningStrike>>? _lightningSub;

  bool initialized = false;
  bool online = true;

  // --------------------------------------------------------------- ciclo de vida
  Future<void> init() async {
    if (initialized) return;
    initialized = true;

    await CacheStore.instance.init();
    await CacheStore.instance.restore(
      [
        RadarService.cacheKey,
        AlertsService.cacheKey,
        TornadoService.cacheKey,
      ],
      {
        RadarService.cacheKey: RadarService.ttl,
        AlertsService.cacheKey: AlertsService.ttl,
        TornadoService.cacheKey: TornadoService.ttl,
      },
    );

    api.startConnectivityWatch();
    api.online.addListener(_onConnectivity);
    online = api.online.value;

    _lightningSub = lightning.strikes.listen((list) {
      strikes = list;
      status[LayerId.lightning] = LayerStatus(
        lastUpdate: lightning.lastMessageAt,
        live: true,
        error: lightning.lastError,
      );
      notifyListeners();
    });
    if (activeLayers.containsKey(LayerId.lightning)) {
      lightning.connect();
    }

    await refreshAll(initial: true);

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (liveMode) _periodicRefresh();
    });
  }

  void _onConnectivity() {
    final nowOnline = api.online.value;
    if (nowOnline != online) {
      online = nowOnline;
      if (online) refreshAll();
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- atualizacoes
  Future<void> refreshAll({bool initial = false}) async {
    await Future.wait([
      refreshRadar(),
      refreshGrid(force: true),
      refreshAlerts(),
      refreshTornadoes(),
    ]);
    if (focusPoint == null) {
      await setFocus(center, fetch: true);
    }
  }

  /// Atualizacao leve executada a cada minuto quando no modo AO VIVO.
  Future<void> _periodicRefresh() async {
    final jobs = <Future>[];
    if (activeLayers.containsKey(LayerId.rainRadar)) {
      jobs.add(refreshRadar());
    }
    if (_needsGrid()) {
      jobs.add(refreshGrid());
    }
    if (activeLayers.containsKey(LayerId.alerts)) {
      jobs.add(refreshAlerts());
    }
    if (activeLayers.containsKey(LayerId.tornadoes)) {
      jobs.add(refreshTornadoes());
    }
    await Future.wait(jobs);
  }

  bool _needsGrid() => activeLayers.keys.any((id) => LayerCatalog.byId(id).kind == LayerKind.grid);

  Future<void> refreshRadar({bool force = false}) async {
    status[LayerId.rainRadar] = (status[LayerId.rainRadar] ?? const LayerStatus()).copyWith(loading: true);
    notifyListeners();
    final res = await radar.timeline(force: force);
    if (res.hasData) {
      final wasLive = liveMode;
      radarTimeline = res.data;
      if (wasLive) {
        frameIndex = (res.data!.all.length - 1).clamp(0, res.data!.all.length - 1);
      } else {
        frameIndex = frameIndex.clamp(0, res.data!.all.length - 1);
      }
      status[LayerId.rainRadar] = LayerStatus(
        lastUpdate: res.data!.generatedAt,
        fromCache: res.fromCache,
        error: res.error,
        live: true,
      );
    } else {
      status[LayerId.rainRadar] = (status[LayerId.rainRadar] ?? const LayerStatus())
          .copyWith(loading: false, error: res.error ?? 'Indisponivel');
    }
    notifyListeners();
  }

  Future<void> refreshGrid({bool force = false}) async {
    final activeGridLayers = activeLayers.keys
        .where((id) => LayerCatalog.byId(id).kind == LayerKind.grid)
        .toList();
    if (activeGridLayers.isEmpty) return;

    final latSpan = _spanForZoom(zoom, isLat: true);
    final lonSpan = _spanForZoom(zoom, isLat: false);

    for (final id in activeGridLayers) {
      status[id] = (status[id] ?? const LayerStatus()).copyWith(loading: true);
    }
    notifyListeners();

    final res = await weather.grid(
      center: center,
      latSpan: latSpan,
      lonSpan: lonSpan,
      rows: gridRows,
      cols: gridCols,
      force: force,
    );

    if (res.hasData && res.data!.isNotEmpty) {
      gridPoints = res.data!;
      gridBounds = LatLngBounds(
        LatLng(
          (center.latitude - latSpan / 2).clamp(-85.0, 85.0),
          (center.longitude - lonSpan / 2).clamp(-180.0, 180.0),
        ),
        LatLng(
          (center.latitude + latSpan / 2).clamp(-85.0, 85.0),
          (center.longitude + lonSpan / 2).clamp(-180.0, 180.0),
        ),
      );
      for (final id in activeGridLayers) {
        status[id] = LayerStatus(
          lastUpdate: res.fetchedAt,
          fromCache: res.fromCache,
          error: res.error,
        );
      }
    } else {
      for (final id in activeGridLayers) {
        status[id] = (status[id] ?? const LayerStatus()).copyWith(loading: false, error: res.error);
      }
    }
    notifyListeners();
  }

  double _spanForZoom(double z, {required bool isLat}) {
    // Aproxima a extensao visivel em graus para o centro do mapa.
    final base = 360.0 / (1 << z.toInt());
    final span = base * (isLat ? 4.5 : 6.5);
    return span.clamp(4.0, isLat ? 60.0 : 90.0);
  }

  Future<void> refreshAlerts() async {
    status[LayerId.alerts] = (status[LayerId.alerts] ?? const LayerStatus()).copyWith(loading: true);
    notifyListeners();
    final res = await alerts.fetchAll();
    if (res.hasData) {
      alertsList = res.data!;
      status[LayerId.alerts] = LayerStatus(
        lastUpdate: res.fetchedAt,
        fromCache: res.fromCache,
        error: res.error,
      );
    } else {
      status[LayerId.alerts] = (status[LayerId.alerts] ?? const LayerStatus())
          .copyWith(loading: false, error: res.error ?? 'Indisponivel');
    }
    notifyListeners();
  }

  Future<void> refreshTornadoes() async {
    status[LayerId.tornadoes] = (status[LayerId.tornadoes] ?? const LayerStatus()).copyWith(loading: true);
    notifyListeners();
    final res = await tornado.fetchAll();
    if (res.hasData) {
      tornadoEvents = res.data!;
      status[LayerId.tornadoes] = LayerStatus(
        lastUpdate: res.fetchedAt,
        fromCache: res.fromCache,
        error: res.error,
      );
    } else {
      status[LayerId.tornadoes] = (status[LayerId.tornadoes] ?? const LayerStatus())
          .copyWith(loading: false, error: res.error ?? 'Indisponivel');
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------- camadas
  bool isLayerActive(LayerId id) => activeLayers.containsKey(id);

  double opacityOf(LayerId id) => activeLayers[id] ?? LayerCatalog.byId(id).defaultOpacity;

  void toggleLayer(LayerId id) {
    if (activeLayers.containsKey(id)) {
      activeLayers.remove(id);
    } else {
      activeLayers[id] = LayerCatalog.byId(id).defaultOpacity;
    }
    if (id == LayerId.lightning) {
      if (activeLayers.containsKey(id)) {
        lightning.connect();
      }
    }
    if (id == LayerId.tornadoes && tornadoEvents.isEmpty) {
      refreshTornadoes();
    }
    if (id == LayerId.alerts && alertsList.isEmpty) {
      refreshAlerts();
    }
    if (LayerCatalog.byId(id).kind == LayerKind.grid) {
      refreshGrid(force: gridPoints.isEmpty);
    }
    if (id == LayerId.rainRadar && radarTimeline == null) {
      refreshRadar();
    }
    notifyListeners();
  }

  void setOpacity(LayerId id, double value) {
    if (activeLayers.containsKey(id)) {
      activeLayers[id] = value.clamp(0.05, 1.0);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------- foco
  Future<void> setFocus(LatLng p, {bool fetch = true}) async {
    center = p;
    notifyListeners();
    if (!fetch) return;
    final res = await weather.currentAt(p);
    if (res.hasData) {
      focusPoint = res.data;
      status[LayerId.temperature] = LayerStatus(
        lastUpdate: res.fetchedAt,
        fromCache: res.fromCache,
        error: res.error,
      );
    }
    notifyListeners();
  }

  /// Busca uma localidade pelo nome e move o mapa para ela.
  Future<GeoPlace?> goToPlace(GeoPlace place) async {
    zoom = 9.0;
    focusPlaceName = place.name;
    await setFocus(place.position);
    if (place.country == 'Brasil') {
      _loadCptecForecast(place.name);
    }
    return place;
  }

  /// Carrega a previsao diaria do CPTEC/INPE para um municipio brasileiro.
  Future<void> _loadCptecForecast(String cityName) async {
    final cities = await weather.searchCity(cityName);
    if (cities.isEmpty) return;
    final daily = await weather.cptecForecast(cities.first.id);
    cptecDaily = daily;
    notifyListeners();
  }

  Future<List<GeoPlace>> searchPlaces(String query) => geocoding.search(query);

  Future<void> locateUser() async {
    locating = true;
    locationError = null;
    notifyListeners();
    try {
      final service = await _requestPermission();
      if (!service) {
        locationError = 'Permissao de localizacao negada';
        locating = false;
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
      userLocation = LatLng(pos.latitude, pos.longitude);
      await setFocus(userLocation!);
      zoom = 8.0;
    } catch (e) {
      locationError = 'Nao foi possivel obter a localizacao';
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  Future<bool> _requestPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  void moveMap(LatLng newCenter, double newZoom) {
    final zoomChanged = (newZoom - zoom).abs() > 0.4;
    center = newCenter;
    zoom = newZoom;
    if (zoomChanged && _needsGrid()) {
      refreshGrid();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- linha do tempo
  List<RadarFrame> get frames => radarTimeline?.all ?? const [];

  RadarFrame? get currentFrame {
    if (frames.isEmpty) return null;
    return frames[frameIndex.clamp(0, frames.length - 1)];
  }

  bool get isLiveFrame => liveMode && radarTimeline != null && frameIndex == frames.length - 1;

  void setFrame(int index) {
    if (frames.isEmpty) return;
    frameIndex = index.clamp(0, frames.length - 1);
    liveMode = frameIndex == frames.length - 1;
    notifyListeners();
  }

  void stepFrame(int delta) {
    if (frames.isEmpty) return;
    setFrame(frameIndex + delta);
  }

  void goLive() {
    liveMode = true;
    playing = false;
    _playTimer?.cancel();
    if (frames.isNotEmpty) {
      frameIndex = frames.length - 1;
    }
    // Recarrega imediatamente para garantir o quadro mais recente.
    refreshRadar(force: true);
    notifyListeners();
  }

  void togglePlay() {
    if (playing) {
      playing = false;
      _playTimer?.cancel();
    } else {
      playing = true;
      liveMode = false;
      if (frames.isNotEmpty && frameIndex >= frames.length - 1) {
        frameIndex = 0;
      }
      _playTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
        if (frames.isEmpty) return;
        frameIndex = (frameIndex + 1) % frames.length;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ consultas
  List<TornadoEvent> get confirmedTornadoes =>
      tornadoEvents.where((e) => e.isConfirmed).toList()
        ..sort((a, b) => (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)));

  List<TornadoEvent> get tornadoWarnings => tornadoEvents.where((e) => e.isWarning).toList();

  List<WeatherAlert> get activeAlerts => alertsList.where((a) => a.isActive).toList();

  List<LightningStrike> get recentStrikes {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 15));
    return strikes.where((s) => s.time.isAfter(cutoff)).toList();
  }

  Staleness stalenessFor(LayerId id) {
    final s = status[id];
    final def = LayerCatalog.byId(id);
    if (s == null) return Staleness.unknown;
    if (s.live && id == LayerId.lightning) {
      return Fmt.staleness(lightning.lastMessageAt, const Duration(minutes: 2));
    }
    return Fmt.staleness(s.lastUpdate, Duration(minutes: def.toleranceMinutes));
  }

  bool get lightningConnected => lightning.connected;

  @override
  void dispose() {
    _playTimer?.cancel();
    _refreshTimer?.cancel();
    _lightningSub?.cancel();
    lightning.dispose();
    api.online.removeListener(_onConnectivity);
    api.dispose();
    super.dispose();
  }
}
