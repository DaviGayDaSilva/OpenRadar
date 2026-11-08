/// Ponto de observacao meteorologica com todos os parametros atmosfericos
/// usados pelo painel de condicoes e pelas camadas de grade.
class WeatherPoint {
  const WeatherPoint({
    required this.lat,
    required this.lon,
    this.time,
    this.temperature,
    this.apparentTemperature,
    this.temperatureMin,
    this.temperatureMax,
    this.humidity,
    this.pressure,
    this.surfacePressure,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.cloudCover,
    this.precipitation,
    this.precipitationProbability,
    this.dewPoint,
    this.cape,
    this.liftedIndex,
    this.freezingLevel,
    this.visibility,
    this.uvIndex,
    this.lightningPotential,
    this.elevation,
  });

  final double lat;
  final double lon;
  final DateTime? time;

  final double? temperature;
  final double? apparentTemperature;
  final double? temperatureMin;
  final double? temperatureMax;
  final double? humidity;
  final double? pressure;
  final double? surfacePressure;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? cloudCover;
  final double? precipitation;
  final double? precipitationProbability;
  final double? dewPoint;
  final double? cape;
  final double? liftedIndex;
  final double? freezingLevel;
  final double? visibility;
  final double? uvIndex;
  final double? lightningPotential;
  final double? elevation;

  /// Indice de severidade convectiva derivado de CAPE e LI (0..1).
  /// Utilizado apenas para colorir celulas; nao representa dado observado novo.
  double get convectiveIntensity {
    final c = (cape ?? 0).clamp(0, 5000) / 5000.0;
    final li = liftedIndex == null ? 0.0 : ((2 - liftedIndex!) / 8.0).clamp(0.0, 1.0);
    return (0.65 * c + 0.35 * li).clamp(0.0, 1.0);
  }

  static double? _d(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  factory WeatherPoint.fromOpenMeteo(Map<String, dynamic> json) {
    final cur = (json['current'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return WeatherPoint(
      lat: _d(json['latitude']) ?? 0,
      lon: _d(json['longitude']) ?? 0,
      time: cur['time'] != null ? DateTime.tryParse('${cur['time']}Z')?.toUtc() : null,
      temperature: _d(cur['temperature_2m']),
      apparentTemperature: _d(cur['apparent_temperature']),
      humidity: _d(cur['relative_humidity_2m']),
      pressure: _d(cur['pressure_msl']),
      surfacePressure: _d(cur['surface_pressure']),
      windSpeed: _d(cur['wind_speed_10m']),
      windDirection: _d(cur['wind_direction_10m']),
      windGust: _d(cur['wind_gusts_10m']),
      cloudCover: _d(cur['cloud_cover']),
      precipitation: _d(cur['precipitation']),
      precipitationProbability: _d(cur['precipitation_probability']),
      dewPoint: _d(cur['dew_point_2m']),
      cape: _d(cur['cape']),
      liftedIndex: _d(cur['lifted_index']),
      freezingLevel: _d(cur['freezing_level_height']),
      visibility: _d(cur['visibility']),
      uvIndex: _d(cur['uv_index']),
      lightningPotential: _d(cur['lightning_potential']),
      elevation: _d(json['elevation']),
    );
  }
}

/// Previsao diaria (CPTEC/INPE e Open-Meteo).
class DailyForecast {
  const DailyForecast({
    required this.date,
    this.min,
    this.max,
    this.condition,
    this.rainProbability,
    this.source = '',
  });

  final DateTime date;
  final double? min;
  final double? max;
  final String? condition;
  final double? rainProbability;
  final String source;
}
