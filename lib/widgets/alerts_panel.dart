import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/weather_alert.dart';
import '../models/weather_layer.dart';
import 'package:latlong2/latlong.dart';

import '../state/weather_controller.dart';

/// Painel de alertas meteorologicos oficiais ativos.
class AlertsPanel extends StatelessWidget {
  const AlertsPanel({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final alerts = controller.activeAlerts;
    final status = controller.status[LayerId.alerts];
    final bySeverity = {
      AlertSeverity.extreme: alerts.where((a) => a.severity == AlertSeverity.extreme).length,
      AlertSeverity.severe: alerts.where((a) => a.severity == AlertSeverity.severe).length,
      AlertSeverity.moderate: alerts.where((a) => a.severity == AlertSeverity.moderate).length,
    };

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text(
                'ALERTAS ATIVOS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Atualizar agora',
                onPressed: controller.refreshAlerts,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          Text(
            'INMET + NOAA/NWS  -  '
            '${status?.lastUpdate != null ? 'atualizado ${Fmt.hourMinute(status!.lastUpdate)}' : 'sem atualizacao'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SevCounter(label: 'Extremo', value: bySeverity[AlertSeverity.extreme]!, color: const Color(0xFFB71C1C)),
              const SizedBox(width: 6),
              _SevCounter(label: 'Severo', value: bySeverity[AlertSeverity.severe]!, color: const Color(0xFFFF4D4D)),
              const SizedBox(width: 6),
              _SevCounter(label: 'Moderado', value: bySeverity[AlertSeverity.moderate]!, color: const Color(0xFFFFC107)),
            ],
          ),
          const SizedBox(height: 8),
          if (status?.error != null && status?.lastUpdate == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Indisponivel: ${status!.error}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 10.5)),
            ),
          if (alerts.isEmpty && status?.loading != true)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Nenhum alerta oficial ativo no momento.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ...alerts.take(30).map((a) => _AlertRow(alert: a, controller: controller)),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.controller});

  final WeatherAlert alert;
  final WeatherController controller;

  Color get _color => switch (alert.severity) {
        AlertSeverity.extreme => const Color(0xFFB71C1C),
        AlertSeverity.severe => const Color(0xFFFF4D4D),
        AlertSeverity.moderate => const Color(0xFFFFC107),
        AlertSeverity.minor => const Color(0xFF64B5F6),
        AlertSeverity.unknown => const Color(0xFF90A4AE),
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alert.polygons.isNotEmpty
          ? () {
              final ring = alert.polygons.first;
              final lat = ring.map((p) => p.latitude).reduce((a, b) => a + b) / ring.length;
              final lon = ring.map((p) => p.longitude).reduce((a, b) => a + b) / ring.length;
              controller.setFocus(LatLng(lat, lon));
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.event.isNotEmpty ? alert.event : alert.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alert.areaDesc.isNotEmpty)
                    Text(
                      alert.areaDesc,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.source}  -  '
                    '${alert.onset != null ? Fmt.dayMonthHourMinute(alert.onset) : 'vigente'}'
                    '${alert.ends != null ? ' ate ${Fmt.hourMinute(alert.ends)}' : ''}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SevCounter extends StatelessWidget {
  const _SevCounter({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700, height: 1)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
