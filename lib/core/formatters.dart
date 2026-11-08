import 'package:intl/intl.dart';

/// Formatacao e utilidades de data/hora usadas na interface.
class Fmt {
  static final DateFormat _hm = DateFormat('HH:mm');
  static final DateFormat _hms = DateFormat('HH:mm:ss');
  static final DateFormat _dmy = DateFormat('dd/MM/yyyy');
  static final DateFormat _dmyhm = DateFormat('dd/MM HH:mm');

  static String hourMinute(DateTime? d) => d == null ? '--:--' : _hm.format(d.toLocal());
  static String hourMinuteSecond(DateTime? d) => d == null ? '--:--:--' : _hms.format(d.toLocal());
  static String dayMonthYear(DateTime? d) => d == null ? '--/--/----' : _dmy.format(d.toLocal());
  static String dayMonthHourMinute(DateTime? d) => d == null ? '--/-- --:--' : _dmyhm.format(d.toLocal());

  /// Idade relativa em texto curto ("agora", "5 min", "2 h", "3 d").
  static String age(DateTime? when, {DateTime? now}) {
    if (when == null) return 'sem dados';
    final ref = now ?? DateTime.now();
    final diff = ref.difference(when.toUtc());
    if (diff.isNegative) return 'agora';
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  /// Classifica atraso de dados conforme tolerancia (em minutos) da fonte.
  static Staleness staleness(DateTime? when, Duration tolerance, {DateTime? now}) {
    if (when == null) return Staleness.unknown;
    final ref = now ?? DateTime.now();
    final age = ref.difference(when.toUtc());
    if (age.isNegative || age <= tolerance) return Staleness.fresh;
    if (age <= tolerance * 3) return Staleness.late;
    return Staleness.stale;
  }

  static String compass(double? degrees) {
    if (degrees == null) return '--';
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'L', 'ESE', 'SE', 'SSE', 'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO'];
    final idx = (((degrees % 360) / 22.5).round()) % 16;
    return dirs[idx];
  }

  static String number(double? v, {int decimals = 0, String unit = ''}) {
    if (v == null || v.isNaN || v.isInfinite) return '--';
    final s = v.toStringAsFixed(decimals);
    return unit.isEmpty ? s : '$s $unit';
  }
}

enum Staleness { fresh, late, stale, unknown }
