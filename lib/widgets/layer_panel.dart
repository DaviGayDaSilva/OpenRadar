import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/weather_layer.dart';
import '../state/weather_controller.dart';

/// Seletor de camadas: ativa/desativa cada camada e ajusta sua opacidade.
/// Exibe o estado de atualizacao (ao vivo, horario, cache, indisponivel).
class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.layers, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'CAMADAS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '${controller.activeLayers.length} ativas',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: LayerCatalog.all.length,
              itemBuilder: (context, i) {
                final def = LayerCatalog.all[i];
                return _LayerTile(controller: controller, def: def);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({required this.controller, required this.def});

  final WeatherController controller;
  final LayerDef def;

  @override
  Widget build(BuildContext context) {
    final active = controller.isLayerActive(def.id);
    final status = controller.status[def.id];
    final stale = controller.stalenessFor(def.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => controller.toggleLayer(def.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: active ? def.color.withValues(alpha: 0.18) : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? def.color.withValues(alpha: 0.6) : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      def.icon,
                      size: 17,
                      color: active ? def.color : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.name,
                          style: TextStyle(
                            color: active ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        _statusLine(status, stale, active),
                      ],
                    ),
                  ),
                  _StatusDot(stale: stale, active: active, live: status?.live ?? false),
                  const SizedBox(width: 6),
                  Switch(
                    value: active,
                    onChanged: (_) => controller.toggleLayer(def.id),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 46, right: 8, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.opacity, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: controller.opacityOf(def.id),
                        min: 0.05,
                        max: 1.0,
                        onChanged: (v) => controller.setOpacity(def.id, v),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${(controller.opacityOf(def.id) * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 4),
        ],
      ),
    );
  }

  Widget _statusLine(LayerStatus? status, Staleness stale, bool active) {
    if (!active) {
      return Text(
        def.source.name,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (status?.loading == true) {
      return const Text('Atualizando...', style: TextStyle(color: AppColors.primary, fontSize: 10));
    }
    if (status?.error != null && status?.lastUpdate == null) {
      return Text(
        'Indisponivel: ${status!.error}',
        style: const TextStyle(color: AppColors.danger, fontSize: 10),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      );
    }
    final when = status?.lastUpdate;
    final label = when == null ? 'Sem dados' : 'Atualizado ${Fmt.hourMinute(when)} (${Fmt.age(when)})';
    final color = switch (stale) {
      Staleness.fresh => AppColors.success,
      Staleness.late => AppColors.warning,
      Staleness.stale => AppColors.danger,
      Staleness.unknown => AppColors.textMuted,
    };
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (status?.fromCache == true) ...[
          const SizedBox(width: 4),
          const Text('(cache)', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
        ],
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.stale, required this.active, required this.live});

  final Staleness stale;
  final bool active;
  final bool live;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      );
    }
    final color = switch (stale) {
      Staleness.fresh => AppColors.success,
      Staleness.late => AppColors.warning,
      Staleness.stale => AppColors.danger,
      Staleness.unknown => AppColors.textMuted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _PulseDot(color: AppColors.danger, size: 6),
          ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

/// Ponto pulsante usado para indicar transmissao ao vivo.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
