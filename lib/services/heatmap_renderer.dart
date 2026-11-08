import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../models/weather_point.dart';

/// Parametros para gerar uma imagem de calor (heatmap) a partir de uma grade
/// de observacoes reais. A imagem e interpolada bilinearmente para suavizar.
class HeatmapRequest {
  const HeatmapRequest({
    required this.values,
    required this.rows,
    required this.cols,
    required this.min,
    required this.max,
    required this.palette,
    this.width = 256,
    this.height = 256,
    this.invert = false,
    this.gamma = 1.0,
  });

  /// Valores por linha (rows x cols), na ordem latitude/longitude.
  final List<double?> values;
  final int rows;
  final int cols;
  final double min;
  final double max;

  /// Paleta: lista de cores do valor minimo ao maximo.
  final List<Color> palette;
  final int width;
  final int height;
  final bool invert;
  final double gamma;
}

/// Renderiza grades de dados reais em PNG (executado em isolate).
class HeatmapRenderer {
  static Uint8List render(HeatmapRequest req) {
    final rows = req.rows;
    final cols = req.cols;
    final image = img.Image(width: req.width, height: req.height, numChannels: 4);

    // Preenche lacunas com o vizinho valido mais proximo.
    final filled = _fillGaps(req.values, rows, cols);

    for (var y = 0; y < req.height; y++) {
      final gy = (y / (req.height - 1)) * (rows - 1);
      final y0 = gy.floor().clamp(0, rows - 1);
      final y1 = (y0 + 1).clamp(0, rows - 1);
      final ty = gy - y0;

      for (var x = 0; x < req.width; x++) {
        final gx = (x / (req.width - 1)) * (cols - 1);
        final x0 = gx.floor().clamp(0, cols - 1);
        final x1 = (x0 + 1).clamp(0, cols - 1);
        final tx = gx - x0;

        final v00 = filled[y0 * cols + x0];
        final v10 = filled[y0 * cols + x1];
        final v01 = filled[y1 * cols + x0];
        final v11 = filled[y1 * cols + x1];

        if (v00 == null && v10 == null && v01 == null && v11 == null) {
          image.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }

        final v0 = _lerp(v00, v10, tx);
        final v1 = _lerp(v01, v11, tx);
        final value = _lerp(v0, v1, ty);
        if (value == null) {
          image.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }

        var t = (value - req.min) / (req.max - req.min);
        if (req.gamma != 1.0) t = math.pow(t.clamp(0.0, 1.0), req.gamma).toDouble();
        t = t.clamp(0.0, 1.0);
        if (req.invert) t = 1 - t;

        final c = _samplePalette(req.palette, t);
        image.setPixelRgba(x, y, (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), 235);
      }
    }
    return img.encodePng(image);
  }

  static double? _lerp(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return a + (b - a) * t;
  }

  static Color _samplePalette(List<Color> palette, double t) {
    if (palette.isEmpty) return const Color(0xFF000000);
    if (palette.length == 1) return palette.first;
    final scaled = t * (palette.length - 1);
    final i = scaled.floor().clamp(0, palette.length - 2);
    final f = scaled - i;
    final a = palette[i];
    final b = palette[i + 1];
    return Color.fromARGB(
      255,
      (a.r + (b.r - a.r) * f).round(),
      (a.g + (b.g - a.g) * f).round(),
      (a.b + (b.b - a.b) * f).round(),
    );
  }

  /// Substitui valores nulos pelo vizinho valido mais proximo (2 passadas).
  static List<double?> _fillGaps(List<double?> values, int rows, int cols) {
    final out = List<double?>.from(values);
    for (var pass = 0; pass < 3; pass++) {
      var changed = false;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final idx = r * cols + c;
          if (out[idx] != null) continue;
          double? sum;
          var count = 0;
          double? acc;
          for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            final nr = r + d[0];
            final nc = c + d[1];
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final v = out[nr * cols + nc];
            if (v != null) {
              acc = (acc ?? 0) + v;
              count++;
            }
          }
          if (count > 0) {
            sum = acc! / count;
            out[idx] = sum;
            changed = true;
          }
        }
      }
      if (!changed) break;
    }
    return out;
  }
}

/// Extrai os valores de uma lista de pontos para um parametro.
List<double?> extractValues(List<WeatherPoint> points, double? Function(WeatherPoint) selector) =>
    points.map(selector).toList();

/// Estatisticas simples (min/max) com percentis para escalas robustas.
class ValueRange {
  const ValueRange(this.min, this.max);
  final double min;
  final double max;

  static ValueRange? from(List<double?> values, {double pLow = 0.02, double pHigh = 0.98}) {
    final v = values.whereType<double>().where((x) => !x.isNaN && x.isFinite).toList()..sort();
    if (v.isEmpty) return null;
    final lo = v[(v.length * pLow).floor().clamp(0, v.length - 1)];
    final hi = v[(v.length * pHigh).ceil().clamp(0, v.length - 1)];
    if ((hi - lo).abs() < 1e-6) return ValueRange(lo - 1, hi + 1);
    return ValueRange(lo, hi);
  }
}

/// Paletas profissionais por parametro (estilo radar meteorologico).
class Palettes {
  static const List<Color> temperature = [
    Color(0xFF3A0CA3), Color(0xFF4361EE), Color(0xFF4CC9F0), Color(0xFF80ED99),
    Color(0xFFFFE066), Color(0xFFFF9E00), Color(0xFFE5383B), Color(0xFF9D0208),
  ];

  static const List<Color> apparent = [
    Color(0xFF2C7DA0), Color(0xFF61A5C2), Color(0xFFA9D6E5), Color(0xFFFFE066),
    Color(0xFFFF9E00), Color(0xFFE5383B), Color(0xFF9D0208),
  ];

  static const List<Color> wind = [
    Color(0xFF0B3954), Color(0xFF087E8B), Color(0xFF3DDC97), Color(0xFFFFE066),
    Color(0xFFFF9E00), Color(0xFFE5383B),
  ];

  static const List<Color> humidity = [
    Color(0xFF7B4B2A), Color(0xFFD9A441), Color(0xFFA8D08D), Color(0xFF4CC9F0),
    Color(0xFF1D4E89), Color(0xFF0B2545),
  ];

  static const List<Color> pressure = [
    Color(0xFF6A4C93), Color(0xFF8AC926), Color(0xFFFFCA3A), Color(0xFFFF7B00),
    Color(0xFFD00000),
  ];

  static const List<Color> clouds = [
    Color(0xFF1B263B), Color(0xFF415A77), Color(0xFF778DA9), Color(0xFFD9E2EC), Color(0xFFF8F9FA),
  ];

  static const List<Color> cape = [
    Color(0xFF2A2A72), Color(0xFF009FFD), Color(0xFF2A9D8F), Color(0xFFFFD166),
    Color(0xFFF4A261), Color(0xFFE63946), Color(0xFF7B2CBF),
  ];

  static const List<Color> hail = [
    Color(0xFF0B3D91), Color(0xFF2E86AB), Color(0xFF7FB069), Color(0xFFFFD166), Color(0xFFE63946),
  ];
}
