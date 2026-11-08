import 'package:latlong2/latlong.dart';

/// Descarga eletrica detectada ao vivo (rede Blitzortung).
class LightningStrike {
  const LightningStrike({required this.time, required this.position, this.amplitude, this.region});

  final DateTime time;
  final LatLng position;

  /// Amplitude relativa informada pela rede (mds). Nao e um dado calibrado em kA.
  final int? amplitude;
  final int? region;
}
