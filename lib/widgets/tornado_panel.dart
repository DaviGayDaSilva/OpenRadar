import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/tornado_event.dart';
import '../models/weather_layer.dart';
import '../services/tornado_service.dart';
import '../state/weather_controller.dart';

/// Secao dedicada ao monitoramento de tornados.
///
/// Distingue claramente:
///  - Avisos oficiais em vigor (NOAA/NWS Tornado Warning).
///  - Ocorrencias confirmadas (NOAA/SPC Storm Reports).
/// Nao exibe observacoes nao verificadas como se fossem confirmacoes.
class TornadoPanel extends StatelessWidget {
  const TornadoPanel({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final warnings = controller.tornadoWarnings;
    final confirmed = controller.confirmedTornadoes;
    final status = controller.status[LayerId.tornadoes];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cyclone, size: 18, color: Color(0xFFFF2D55)),
              const SizedBox(width: 8),
              const Text(
                'TORNADOS',
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
                onPressed: controller.refreshTornadoes,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Fonte: ${status != null ? 'NOAA/NWS + SPC' : 'NOAA/NWS + SPC'}  -  '
            '${status?.lastUpdate != null ? 'atualizado ${Fmt.hourMinute(status!.lastUpdate)}' : 'sem atualizacao'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 10),

          // Contadores
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Avisos em vigor',
                  value: warnings.length,
                  color: const Color(0xFFFF7043),
                  icon: Icons.campaign,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Counter(
                  label: 'Confirmados hoje',
                  value: confirmed.length,
                  color: const Color(0xFFFF2D55),
                  icon: Icons.verified,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (status?.error != null && status?.lastUpdate == null)
            _Notice(
              icon: Icons.cloud_off,
              color: AppColors.danger,
              text: 'Sem conexao com as fontes de tornados: ${status!.error}',
            ),

          if (warnings.isEmpty && confirmed.isEmpty)
            const _Notice(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              text: 'Nenhum aviso de tornado em vigor e nenhuma ocorrencia confirmada '
                  'registrada pela NOAA no momento.',
            ),

          if (warnings.isNotEmpty) ...[
            const _SectionTitle('AVISOS OFICIAIS EM VIGOR'),
            ...warnings.take(20).map((t) => _TornadoRow(event: t, controller: controller)),
            const SizedBox(height: 6),
          ],

          if (confirmed.isNotEmpty) ...[
            const _SectionTitle('OCORRENCIAS CONFIRMADAS (SPC Storm Reports)'),
            ...confirmed.take(25).map((t) => _TornadoRow(event: t, controller: controller)),
          ],

          const SizedBox(height: 6),
          const _Notice(
            icon: Icons.info_outline,
            color: AppColors.textMuted,
            text: 'Avisos = areas sob monitoramento oficial (nao confirmam tornado no solo). '
                'Confirmados = relatorios oficiais do SPC. Nenhum registro e estimado ou simulado.',
          ),
        ],
      ),
    );
  }
}

class _TornadoRow extends StatelessWidget {
  const _TornadoRow({required this.event, required this.controller});

  final TornadoEvent event;
  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final confirmed = event.isConfirmed;
    final color = confirmed ? const Color(0xFFFF2D55) : const Color(0xFFFF7043);
    return InkWell(
      onTap: () => controller.setFocus(event.position),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Icon(confirmed ? Icons.verified : Icons.campaign, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.fScale != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.fScale!,
                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          confirmed
                              ? '${event.location}${event.state.isNotEmpty ? ' - ${TornadoService.stateName(event.state)}' : ''}'
                              : (event.areaDesc.isNotEmpty ? event.areaDesc : 'Area sob aviso'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.dayMonthHourMinute(event.time)}'
                    '${event.expires != null ? '  -  valido ate ${Fmt.hourMinute(event.expires)}' : ''}'
                    '  -  ${event.lat.toStringAsFixed(2)}, ${event.lon.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  if (event.comments.isNotEmpty)
                    Text(
                      event.comments,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    event.source,
                    style: const TextStyle(color: AppColors.primaryDim, fontSize: 9),
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

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700, height: 1.0),
              ),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 10.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
