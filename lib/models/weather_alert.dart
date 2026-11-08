import 'package:latlong2/latlong.dart';

/// Severidade normalizada entre fontes distintas (INMET, NOAA/NWS, CPTEC).
enum AlertSeverity { minor, moderate, severe, extreme, unknown }

/// Aviso meteorologico oficial, com poligono quando a fonte disponibiliza.
class WeatherAlert {
  const WeatherAlert({
    required this.id,
    required this.title,
    required this.source,
    required this.severity,
    this.description = '',
    this.instruction = '',
    this.areaDesc = '',
    this.onset,
    this.ends,
    this.sent,
    this.polygons = const [],
    this.event = '',
  });

  final String id;
  final String title;
  final String event;
  final String source;
  final AlertSeverity severity;
  final String description;
  final String instruction;
  final String areaDesc;
  final DateTime? onset;
  final DateTime? ends;
  final DateTime? sent;

  /// Lista de aneis de coordenadas (cada anel e um poligono fechado).
  final List<List<LatLng>> polygons;

  bool get isActive {
    final now = DateTime.now().toUtc();
    if (onset != null && onset!.isAfter(now)) return false;
    if (ends != null && ends!.isBefore(now)) return false;
    return true;
  }

  static AlertSeverity severityFromText(String? text) {
    switch ((text ?? '').toLowerCase()) {
      case 'extreme':
      case 'grande perigo':
        return AlertSeverity.extreme;
      case 'severe':
      case 'perigo':
        return AlertSeverity.severe;
      case 'moderate':
      case 'perigo potencial':
        return AlertSeverity.moderate;
      case 'minor':
      case 'unknown':
        return AlertSeverity.minor;
      default:
        return AlertSeverity.unknown;
    }
  }
}
