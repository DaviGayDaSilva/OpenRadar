/// Quadro individual do radar de chuva (RainViewer).
class RadarFrame {
  const RadarFrame({required this.time, required this.path, this.isForecast = false});

  final DateTime time;
  final String path;
  final bool isForecast;

  factory RadarFrame.fromJson(Map<String, dynamic> json, {bool forecast = false}) => RadarFrame(
        time: DateTime.fromMillisecondsSinceEpoch((json['time'] as num).toInt() * 1000, isUtc: true),
        path: json['path'] as String,
        isForecast: forecast,
      );
}

/// Conjunto de quadros do radar, com metadados do servidor de tiles.
class RadarTimeline {
  const RadarTimeline({
    required this.host,
    required this.past,
    required this.nowcast,
    required this.generatedAt,
  });

  final String host;
  final List<RadarFrame> past;
  final List<RadarFrame> nowcast;
  final DateTime generatedAt;

  List<RadarFrame> get all => [...past, ...nowcast];

  RadarFrame? get latest => past.isNotEmpty ? past.last : null;

  /// URL de tile para o quadro, no esquema de cores 4 (Universal Blue) e
  /// suavizacao 1, tamanho 256 e zoom maximo 6 por tile.
  String tileUrl(RadarFrame frame, {int colorScheme = 4, bool smooth = true, bool snow = true}) {
    final s = smooth ? 1 : 0;
    final sn = snow ? 1 : 0;
    return '$host${frame.path}/256/{z}/{x}/{y}/$colorScheme/${s}_$sn.png';
  }

  factory RadarTimeline.fromJson(Map<String, dynamic> json) {
    final radar = (json['radar'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final past = (radar['past'] as List? ?? const [])
        .map((e) => RadarFrame.fromJson(e as Map<String, dynamic>))
        .toList();
    final nowcast = (radar['nowcast'] as List? ?? const [])
        .map((e) => RadarFrame.fromJson(e as Map<String, dynamic>, forecast: true))
        .toList();
    return RadarTimeline(
      host: json['host'] as String? ?? 'https://tilecache.rainviewer.com',
      past: past,
      nowcast: nowcast,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['generated'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
    );
  }
}
