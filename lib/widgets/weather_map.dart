import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_theme.dart';


import '../models/tornado_event.dart';
import '../models/weather_alert.dart';
import '../models/weather_layer.dart';
import '../models/weather_point.dart';
import '../services/heatmap_renderer.dart';
import '../state/weather_controller.dart';

/// Mapa meteorologico interativo com todas as camadas do OpenRadar.
class WeatherMapView extends StatefulWidget {
  const WeatherMapView({
    super.key,
    required this.controller,
    this.mapController,
    this.onMapTap,
  });

  final WeatherController controller;
  final MapController? mapController;
  final void Function(LatLng)? onMapTap;

  @override
  State<WeatherMapView> createState() => _WeatherMapViewState();
}

class _WeatherMapViewState extends State<WeatherMapView> {
  late final MapController _mapController = widget.mapController ?? MapController();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return FlutterMap(
      key: const ValueKey('openradar_map'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: c.center,
        initialZoom: c.zoom,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: AppColors.background,
        onPositionChanged: (camera, hasGesture) {
          c.moveMap(camera.center, camera.zoom);
        },
        onTap: (tapPos, latlng) {
          widget.onMapTap?.call(latlng);
          c.setFocus(latlng);
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // Mapa base: cidades, estados, paises e fronteiras.
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'br.com.openradar.openradar',
          maxNativeZoom: 19,
          tileProvider: NetworkTileProvider(),
          retinaMode: RetinaMode.isHighDensity(context),
        ),

        // Camadas de grade interpolada (temperatura, vento, etc.).
        if (_activeGridLayers(c).isNotEmpty && c.gridPoints.isNotEmpty && c.gridBounds != null)
          HeatmapOverlayLayer(
            key: ValueKey('grid_${c.gridBounds}_${c.gridPoints.length}'),
            points: c.gridPoints,
            rows: c.gridRows,
            cols: c.gridCols,
            bounds: c.gridBounds!,
            activeLayers: _activeGridLayers(c),
            opacities: {for (final id in _activeGridLayers(c)) id: c.opacityOf(id)},
          ),

        // Radar de chuva animado.
        if (c.isLayerActive(LayerId.rainRadar) && c.radarTimeline != null && c.currentFrame != null)
          TileLayer(
            key: ValueKey('radar_${c.currentFrame!.path}'),
            urlTemplate: c.radarTimeline!.tileUrl(c.currentFrame!),
            userAgentPackageName: 'br.com.openradar.openradar',
            maxNativeZoom: 12,
            tileProvider: NetworkTileProvider(),
            tileBuilder: (context, tileWidget, tile) => Opacity(
              opacity: c.opacityOf(LayerId.rainRadar),
              child: tileWidget,
            ),
          ),

        // Alertas meteorologicos oficiais (poligonos).
        if (c.isLayerActive(LayerId.alerts))
          PolygonLayer(
            polygons: _alertPolygons(c),
          ),

        // Tornados: areas sob aviso e ocorrencias confirmadas.
        if (c.isLayerActive(LayerId.tornadoes))
          PolygonLayer(polygons: _tornadoWarningCircles(c)),

        // Marcadores: raios ao vivo, tornados, alertas e localizacao.
        // Construido como filho do mapa para acessar o MapCamera ambiente.
        MarkerOverlay(controller: c),

        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap', onTap: null),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }

  List<LayerId> _activeGridLayers(WeatherController c) => c.activeLayers.keys
      .where((id) => LayerCatalog.byId(id).kind == LayerKind.grid)
      .toList();

  // ------------------------------------------------------------- alertas
  List<Polygon> _alertPolygons(WeatherController c) {
    final opacity = c.opacityOf(LayerId.alerts);
    final polygons = <Polygon>[];
    for (final a in c.activeAlerts) {
      if (a.polygons.isEmpty) continue;
      final color = _severityColor(a.severity);
      for (final ring in a.polygons) {
        if (ring.length < 3) continue;
        polygons.add(Polygon(
          points: ring,
          color: color.withValues(alpha: 0.16 * opacity / 0.6),
          borderColor: color.withValues(alpha: 0.95),
          borderStrokeWidth: 1.4,
        ));
      }
    }
    return polygons;
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.extreme:
        return const Color(0xFFB71C1C);
      case AlertSeverity.severe:
        return const Color(0xFFFF4D4D);
      case AlertSeverity.moderate:
        return const Color(0xFFFFC107);
      case AlertSeverity.minor:
        return const Color(0xFF64B5F6);
      case AlertSeverity.unknown:
        return const Color(0xFF90A4AE);
    }
  }

  /// Representa avisos de tornado como circulos destacados sobre o centro
  /// da area avisada (o NWS fornece poligono; usamos o centro para o marcador).
  List<Polygon> _tornadoWarningCircles(WeatherController c) {
    return c.tornadoWarnings.map((t) {
      return Polygon(
        points: _circle(t.position, 0.35),
        color: const Color(0x33FF2D55),
        borderColor: const Color(0xFFFF2D55),
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<LatLng> _circle(LatLng center, double radiusDeg, {int segments = 28}) {
    final pts = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final a = 2 * math.pi * i / segments;
      pts.add(LatLng(
        center.latitude + radiusDeg * 0.6 * math.cos(a),
        center.longitude + radiusDeg * math.sin(a),
      ));
    }
    return pts;
  }
}

/// Camada de marcadores construida dentro do mapa, para acessar o camera
/// ambiente (usado no culling de elementos fora da area visivel).
class MarkerOverlay extends StatelessWidget {
  const MarkerOverlay({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final markers = <Marker>[];
    final c = controller;

    // Raios ao vivo: somente dentro da area visivel, com brilho por idade.
    if (c.isLayerActive(LayerId.lightning)) {
      final now = DateTime.now().toUtc();
      final visible = c.strikes.where((s) => bounds.contains(s.position)).toList();
      final limited = visible.length > 1200 ? visible.sublist(visible.length - 1200) : visible;
      for (final s in limited) {
        final ageMin = now.difference(s.time).inSeconds / 60.0;
        final t = (1 - (ageMin / 45)).clamp(0.0, 1.0);
        final color = Color.lerp(const Color(0x66FFD54F), const Color(0xFFFFF176), t)!;
        markers.add(Marker(
          point: s.position,
          width: 10,
          height: 10,
          child: _LightningDot(color: color, size: 4 + 5 * t),
        ));
      }
    }

    // Tornados: avisos e ocorrencias confirmadas.
    if (c.isLayerActive(LayerId.tornadoes)) {
      for (final t in c.tornadoEvents) {
        if (!bounds.contains(t.position)) continue;
        markers.add(Marker(
          point: t.position,
          width: 46,
          height: 46,
          child: _TornadoMarker(event: t),
        ));
      }
    }

    // Alertas: pino no centroide quando nao ha poligono desenhado.
    if (c.isLayerActive(LayerId.alerts)) {
      for (final a in c.activeAlerts) {
        final center = _center(a);
        if (center == null || !bounds.contains(center)) continue;
        markers.add(Marker(
          point: center,
          width: 34,
          height: 34,
          child: _AlertMarker(severity: a.severity),
        ));
      }
    }

    // Localizacao do usuario.
    final user = c.userLocation;
    if (user != null) {
      markers.add(Marker(
        point: user,
        width: 26,
        height: 26,
        child: const _UserLocationMarker(),
      ));
    }

    // Ponto selecionado.
    final focus = c.focusPoint;
    if (focus != null) {
      markers.add(Marker(
        point: LatLng(focus.lat, focus.lon),
        width: 30,
        height: 30,
        child: const _FocusMarker(),
      ));
    }

    return MarkerLayer(markers: markers);
  }

  LatLng? _center(WeatherAlert a) {
    if (a.polygons.isEmpty) return null;
    final ring = a.polygons.first;
    if (ring.isEmpty) return null;
    final lat = ring.map((p) => p.latitude).reduce((x, y) => x + y) / ring.length;
    final lon = ring.map((p) => p.longitude).reduce((x, y) => x + y) / ring.length;
    return LatLng(lat, lon);
  }
}

/// Ponto de descarga eletrica com brilho.
class _LightningDot extends StatelessWidget {
  const _LightningDot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: size, spreadRadius: size / 3),
          ],
        ),
      ),
    );
  }
}

class _TornadoMarker extends StatelessWidget {
  const _TornadoMarker({required this.event});
  final TornadoEvent event;

  @override
  Widget build(BuildContext context) {
    final confirmed = event.isConfirmed;
    final color = confirmed ? const Color(0xFFFF2D55) : const Color(0xFFFF7043);
    return Tooltip(
      message: confirmed
          ? 'Tornado confirmado${event.fScale != null ? ' (${event.fScale})' : ''} - ${event.location}'
          : 'Aviso de tornado - ${event.areaDesc}',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.22),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(Icons.cyclone, color: color, size: 22),
      ),
    );
  }
}

class _AlertMarker extends StatelessWidget {
  const _AlertMarker({required this.severity});
  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      AlertSeverity.extreme => const Color(0xFFB71C1C),
      AlertSeverity.severe => const Color(0xFFFF4D4D),
      AlertSeverity.moderate => const Color(0xFFFFC107),
      AlertSeverity.minor => const Color(0xFF64B5F6),
      AlertSeverity.unknown => const Color(0xFF90A4AE),
    };
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface.withValues(alpha: 0.75),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(Icons.warning_amber_rounded, color: color, size: 18),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _FocusMarker extends StatelessWidget {
  const _FocusMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.place, color: AppColors.accent, size: 30);
  }
}

/// Camada que renderiza todas as grades ativas como imagens sobrepostas.
class HeatmapOverlayLayer extends StatefulWidget {
  const HeatmapOverlayLayer({
    super.key,
    required this.points,
    required this.rows,
    required this.cols,
    required this.bounds,
    required this.activeLayers,
    required this.opacities,
  });

  final List<WeatherPoint> points;
  final int rows;
  final int cols;
  final LatLngBounds bounds;
  final List<LayerId> activeLayers;
  final Map<LayerId, double> opacities;

  @override
  State<HeatmapOverlayLayer> createState() => _HeatmapOverlayLayerState();
}

class _HeatmapOverlayLayerState extends State<HeatmapOverlayLayer> {
  final Map<LayerId, Uint8List> _images = {};
  bool _computing = false;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant HeatmapOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points) ||
        oldWidget.activeLayers.length != widget.activeLayers.length ||
        !_sameLayers(oldWidget.activeLayers, widget.activeLayers)) {
      _compute();
    }
  }

  bool _sameLayers(List<LayerId> a, List<LayerId> b) {
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }

  Future<void> _compute() async {
    if (_computing) return;
    _computing = true;
    try {
      final results = await Future.wait(widget.activeLayers.map(_renderLayer));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < widget.activeLayers.length; i++) {
          if (results[i] != null) _images[widget.activeLayers[i]] = results[i]!;
        }
      });
    } finally {
      _computing = false;
    }
  }

  Future<Uint8List?> _renderLayer(LayerId id) async {
    final spec = _specFor(id);
    if (spec == null) return null;
    final values = extractValues(widget.points, spec.selector);
    final range = ValueRange.from(values);
    if (range == null) return null;
    final req = HeatmapRequest(
      values: values,
      rows: widget.rows,
      cols: widget.cols,
      min: spec.minOverride ?? range.min,
      max: spec.maxOverride ?? range.max,
      palette: spec.palette,
      width: 256,
      height: 256,
      invert: spec.invert,
      gamma: spec.gamma,
    );
    return compute(HeatmapRenderer.render, req);
  }

  _LayerSpec? _specFor(LayerId id) {
    switch (id) {
      case LayerId.temperature:
        return _LayerSpec((p) => p.temperature, Palettes.temperature);
      case LayerId.apparentTemperature:
        return _LayerSpec((p) => p.apparentTemperature, Palettes.apparent);
      case LayerId.wind:
        return _LayerSpec((p) => p.windSpeed, Palettes.wind);
      case LayerId.gusts:
        return _LayerSpec((p) => p.windGust, Palettes.wind);
      case LayerId.humidity:
        return _LayerSpec((p) => p.humidity, Palettes.humidity);
      case LayerId.pressure:
        return _LayerSpec((p) => p.pressure, Palettes.pressure);
      case LayerId.clouds:
        return _LayerSpec((p) => p.cloudCover, Palettes.clouds, minOverride: 0, maxOverride: 100);
      case LayerId.storms:
        return _LayerSpec(
          (p) => p.cape,
          Palettes.cape,
          minOverride: 0,
          maxOverride: 3000,
          gamma: 0.75,
        );
      case LayerId.hail:
        return _LayerSpec(
          (p) => p.freezingLevel,
          Palettes.hail,
          minOverride: 0,
          maxOverride: 5000,
          invert: true,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = <OverlayImage>[];
    for (final id in widget.activeLayers) {
      final bytes = _images[id];
      if (bytes == null) continue;
      images.add(OverlayImage(
        bounds: widget.bounds,
        opacity: widget.opacities[id] ?? 0.75,
        imageProvider: MemoryImage(bytes),
        gaplessPlayback: true,
      ));
    }
    if (images.isEmpty) return const SizedBox.shrink();
    return OverlayImageLayer(overlayImages: images);
  }
}

class _LayerSpec {
  _LayerSpec(
    this.selector,
    this.palette, {
    this.minOverride,
    this.maxOverride,
    this.invert = false,
    this.gamma = 1.0,
  });

  final double? Function(WeatherPoint) selector;
  final List<ui.Color> palette;
  final double? minOverride;
  final double? maxOverride;
  final bool invert;
  final double gamma;
}
