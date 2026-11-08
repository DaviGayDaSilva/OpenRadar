import 'package:flutter/material.dart';

/// Identificadores de cada camada exibivel no mapa.
enum LayerId {
  temperature,
  rainRadar,
  tornadoes,
  storms,
  lightning,
  wind,
  gusts,
  humidity,
  pressure,
  clouds,
  hail,
  apparentTemperature,
  alerts,
}

/// Modo de renderizacao da camada sobre o mapa.
enum LayerKind {
  /// Camada raster (tiles de radar).
  raster,

  /// Grade de valores interpolada a partir de dados pontuais reais.
  grid,

  /// Marcadores/vetores (raios, tornados, alertas).
  markers,
}

/// Fonte de dados associada a camada. Camadas sem fonte real ficam marcadas
/// como indisponiveis e a interface informa isso explicitamente.
class LayerSource {
  const LayerSource({required this.name, required this.url, this.available = true, this.note = ''});

  final String name;
  final String url;
  final bool available;
  final String note;
}

/// Definicao de uma camada: metadados, unidade, cor e fonte.
class LayerDef {
  const LayerDef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.kind,
    required this.color,
    required this.unit,
    required this.source,
    this.description = '',
    this.toleranceMinutes = 30,
    this.defaultOpacity = 0.75,
  });

  final LayerId id;
  final String name;
  final String shortName;
  final IconData icon;
  final LayerKind kind;
  final Color color;
  final String unit;
  final LayerSource source;
  final String description;

  /// Tolerancia de atraso aceitavel para considerar o dado "atual".
  final int toleranceMinutes;
  final double defaultOpacity;
}

/// Catalogo completo das camadas do OpenRadar.
class LayerCatalog {
  static const List<LayerDef> all = [
    LayerDef(
      id: LayerId.temperature,
      name: 'Temperatura',
      shortName: 'Temp',
      icon: Icons.thermostat,
      kind: LayerKind.grid,
      color: Color(0xFFFF7043),
      unit: '°C',
      toleranceMinutes: 30,
      description: 'Temperatura do ar a 2 m sobre a grade de pontos reais.',
      source: LayerSource(name: 'Open-Meteo / ICON-EU', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.rainRadar,
      name: 'Radar de chuva',
      shortName: 'Radar',
      icon: Icons.radar,
      kind: LayerKind.raster,
      color: Color(0xFF29D2E4),
      unit: 'dBZ',
      toleranceMinutes: 20,
      description: 'Intensidade e deslocamento da precipitacao por radar.',
      source: LayerSource(name: 'RainViewer', url: 'https://www.rainviewer.com'),
    ),
    LayerDef(
      id: LayerId.tornadoes,
      name: 'Tornados',
      shortName: 'Tornado',
      icon: Icons.cyclone,
      kind: LayerKind.markers,
      color: Color(0xFFFF2D55),
      unit: '',
      toleranceMinutes: 60,
      description: 'Avisos oficiais e ocorrencias confirmadas de tornado.',
      source: LayerSource(name: 'NOAA/NWS + SPC Storm Reports', url: 'https://www.spc.noaa.gov/climo/reports/'),
    ),
    LayerDef(
      id: LayerId.storms,
      name: 'Tempestades',
      shortName: 'Tempest.',
      icon: Icons.thunderstorm,
      kind: LayerKind.grid,
      color: Color(0xFFB388FF),
      unit: 'J/kg',
      toleranceMinutes: 30,
      description: 'Celulas convectivas pela energia potencial (CAPE) e indice levantado.',
      source: LayerSource(name: 'Open-Meteo (CAPE/LI)', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.lightning,
      name: 'Raios',
      shortName: 'Raios',
      icon: Icons.bolt,
      kind: LayerKind.markers,
      color: Color(0xFFFFD54F),
      unit: '',
      toleranceMinutes: 5,
      description: 'Descargas eletricas detectadas ao vivo pela rede Blitzortung.',
      source: LayerSource(name: 'Blitzortung.org (tempo real)', url: 'https://www.blitzortung.org'),
    ),
    LayerDef(
      id: LayerId.wind,
      name: 'Ventos',
      shortName: 'Vento',
      icon: Icons.air,
      kind: LayerKind.grid,
      color: Color(0xFF4FC3F7),
      unit: 'km/h',
      toleranceMinutes: 30,
      description: 'Velocidade e direcao do vento a 10 m.',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.gusts,
      name: 'Rajadas',
      shortName: 'Rajada',
      icon: Icons.air,
      kind: LayerKind.grid,
      color: Color(0xFF26C6DA),
      unit: 'km/h',
      toleranceMinutes: 30,
      description: 'Intensidade das rajadas de vento.',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.humidity,
      name: 'Umidade',
      shortName: 'Umid.',
      icon: Icons.water_drop,
      kind: LayerKind.grid,
      color: Color(0xFF64B5F6),
      unit: '%',
      toleranceMinutes: 30,
      description: 'Umidade relativa do ar a 2 m.',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.pressure,
      name: 'Pressao atmosferica',
      shortName: 'Pressao',
      icon: Icons.speed,
      kind: LayerKind.grid,
      color: Color(0xFFFF8A65),
      unit: 'hPa',
      toleranceMinutes: 30,
      description: 'Pressao ao nivel medio do mar.',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.clouds,
      name: 'Nuvens',
      shortName: 'Nuvens',
      icon: Icons.cloud,
      kind: LayerKind.grid,
      color: Color(0xFFB0BEC5),
      unit: '%',
      toleranceMinutes: 30,
      description: 'Cobertura de nuvens total.',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.hail,
      name: 'Granizo',
      shortName: 'Granizo',
      icon: Icons.grain,
      kind: LayerKind.grid,
      color: Color(0xFF9CCC65),
      unit: 'mm',
      toleranceMinutes: 30,
      description: 'Probabilidade/altura de granizo prevista e nivel de congelamento.',
      source: LayerSource(name: 'Open-Meteo (hail/freezing level)', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.apparentTemperature,
      name: 'Sensacao termica',
      shortName: 'Sensacao',
      icon: Icons.device_thermostat,
      kind: LayerKind.grid,
      color: Color(0xFFFFAB91),
      unit: '°C',
      toleranceMinutes: 30,
      description: 'Temperatura aparente (sensacao termica).',
      source: LayerSource(name: 'Open-Meteo', url: 'https://open-meteo.com'),
    ),
    LayerDef(
      id: LayerId.alerts,
      name: 'Alertas meteorologicos',
      shortName: 'Alertas',
      icon: Icons.warning_amber,
      kind: LayerKind.markers,
      color: Color(0xFFFFC107),
      unit: '',
      toleranceMinutes: 60,
      description: 'Avisos oficiais de perigo (INMET, NOAA/NWS, CPTEC).',
      source: LayerSource(
        name: 'INMET + NOAA/NWS + CPTEC',
        url: 'https://portal.inmet.gov.br',
      ),
    ),
  ];

  static LayerDef byId(LayerId id) => all.firstWhere((l) => l.id == id);
}
