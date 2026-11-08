import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/weather_layer.dart';

import '../state/weather_controller.dart';

/// Painel de condicoes atuais do ponto selecionado no mapa.
class ConditionsPanel extends StatelessWidget {
  const ConditionsPanel({super.key, required this.controller, this.onClose});

  final WeatherController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = controller.focusPoint;
    if (p == null) {
      return GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 10),
            Text('Obtendo condicoes do ponto...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    final tempStatus = controller.status[LayerId.temperature];
    final when = tempStatus?.lastUpdate ?? p.time;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${Fmt.number(p.temperature, decimals: 1)}°C',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sensacao ${Fmt.number(p.apparentTemperature, decimals: 1)}°C',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniStat(
                    icon: Icons.arrow_upward,
                    label: 'Max',
                    value: Fmt.number(p.temperatureMax, decimals: 0, unit: '°'),
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 4),
                  _MiniStat(
                    icon: Icons.arrow_downward,
                    label: 'Min',
                    value: Fmt.number(p.temperatureMin, decimals: 0, unit: '°'),
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(
                icon: Icons.air,
                label: 'Vento',
                value: '${Fmt.number(p.windSpeed, decimals: 0)} km/h',
                sub: Fmt.compass(p.windDirection),
              ),
              _Stat(
                icon: Icons.air,
                label: 'Rajadas',
                value: '${Fmt.number(p.windGust, decimals: 0)} km/h',
              ),
              _Stat(
                icon: Icons.water_drop,
                label: 'Umidade',
                value: '${Fmt.number(p.humidity, decimals: 0)}%',
              ),
              _Stat(
                icon: Icons.speed,
                label: 'Pressao',
                value: '${Fmt.number(p.pressure, decimals: 0)} hPa',
              ),
              _Stat(
                icon: Icons.grain,
                label: 'Chuva (prob.)',
                value: '${Fmt.number(p.precipitationProbability, decimals: 0)}%',
              ),
              _Stat(
                icon: Icons.water,
                label: 'Precipitacao',
                value: '${Fmt.number(p.precipitation, decimals: 1)} mm',
              ),
              if (p.dewPoint != null)
                _Stat(
                  icon: Icons.thermostat_auto,
                  label: 'Orvalho',
                  value: '${Fmt.number(p.dewPoint, decimals: 1)}°C',
                ),
              if (p.cloudCover != null)
                _Stat(
                  icon: Icons.cloud,
                  label: 'Nuvens',
                  value: '${Fmt.number(p.cloudCover, decimals: 0)}%',
                ),
              if (p.cape != null)
                _Stat(
                  icon: Icons.thunderstorm,
                  label: 'CAPE',
                  value: '${Fmt.number(p.cape, decimals: 0)} J/kg',
                ),
              if (p.visibility != null)
                _Stat(
                  icon: Icons.visibility,
                  label: 'Visibilidade',
                  value: '${Fmt.number((p.visibility ?? 0) / 1000, decimals: 1)} km',
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.cptecDaily.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                const Text('Previsao CPTEC/INPE',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                if (controller.focusPlaceName != null)
                  Text('  -  ${controller.focusPlaceName}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.cptecDaily.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = controller.cptecDaily[i];
                  return Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.dayMonthHourMinute(d.date).split(' ').first,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text(
                          '${Fmt.number(d.max, decimals: 0)}° / ${Fmt.number(d.min, decimals: 0)}°',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          d.condition ?? '',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(
                tempStatus?.fromCache == true ? Icons.cloud_off : Icons.schedule,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Ultima atualizacao: ${Fmt.hourMinuteSecond(when)}'
                  '${tempStatus?.fromCache == true ? ' (cache)' : ''}  -  '
                  '${Fmt.number(p.lat, decimals: 3)}, ${Fmt.number(p.lon, decimals: 3)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, this.sub});

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null)
            Text(sub!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$label ', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
