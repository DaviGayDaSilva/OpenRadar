import 'package:latlong2/latlong.dart';

/// Classificacao de uma ocorrencia de tornado.
/// NUNCA inventamos ocorrencias: cada registro vem de relatorio oficial
/// (NOAA/SPC Storm Reports) ou de aviso oficial em vigor (NOAA/NWS).
enum TornadoStatus {
  /// Relatorio oficial de tornado confirmado no solo (SPC Storm Reports).
  confirmed,

  /// Aviso de tornado em vigor emitido pelo orgao oficial (NWS Tornado Warning).
  warning,
}

/// Ocorrencia ou aviso de tornado, sempre com fonte e horario originais.
class TornadoEvent {
  const TornadoEvent({
    required this.status,
    required this.source,
    required this.lat,
    required this.lon,
    this.time,
    this.fScale,
    this.location = '',
    this.county = '',
    this.state = '',
    this.comments = '',
    this.areaDesc = '',
    this.expires,
    this.eventId = '',
  });

  final TornadoStatus status;
  final String source;
  final double lat;
  final double lon;
  final DateTime? time;

  /// Escala Fujita/EF informada no relatorio oficial. Nulo quando nao informada.
  final String? fScale;
  final String location;
  final String county;
  final String state;
  final String comments;
  final String areaDesc;
  final DateTime? expires;
  final String eventId;

  LatLng get position => LatLng(lat, lon);

  bool get isConfirmed => status == TornadoStatus.confirmed;
  bool get isWarning => status == TornadoStatus.warning;
}
