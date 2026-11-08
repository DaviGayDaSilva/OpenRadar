import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';

import '../state/weather_controller.dart';

/// Barra temporal do radar: retroceder, reproduzir, pausar, avancar e voltar
/// ao AO VIVO. Mostra o horario de cada imagem e marca o quadro atual.
class RadarTimelineBar extends StatelessWidget {
  const RadarTimelineBar({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final frames = controller.frames;
    if (frames.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text('Carregando quadros do radar...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            _LiveButton(controller: controller, enabled: false),
          ],
        ),
      );
    }

    final index = controller.frameIndex.clamp(0, frames.length - 1);
    final frame = frames[index];
    final isLive = controller.isLiveFrame;
    final now = DateTime.now().toUtc();
    final ageMin = now.difference(frame.time).inMinutes;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Controles de reproducao
              _IconBtn(
                icon: Icons.skip_previous,
                tooltip: 'Quadro anterior',
                onTap: () => controller.stepFrame(-1),
              ),
              _IconBtn(
                icon: controller.playing ? Icons.pause : Icons.play_arrow,
                tooltip: controller.playing ? 'Pausar' : 'Reproduzir animacao',
                onTap: controller.togglePlay,
                highlighted: controller.playing,
              ),
              _IconBtn(
                icon: Icons.skip_next,
                tooltip: 'Proximo quadro',
                onTap: () => controller.stepFrame(1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          Fmt.hourMinute(frame.time),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (frame.isForecast)
                          _Chip(label: 'PREVISAO', color: AppColors.accent)
                        else
                          _Chip(
                            label: ageMin <= 15 ? 'RECENTE' : '${ageMin}min',
                            color: ageMin <= 15 ? AppColors.success : AppColors.textMuted,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          '${index + 1}/${frames.length}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '${Fmt.dayMonthYear(frame.time)}  -  fonte: RainViewer',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _LiveButton(controller: controller, enabled: true, active: isLive),
            ],
          ),
          const SizedBox(height: 6),
          // Faixa temporal com marcador arrastavel
          SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Trilha
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Progresso
                    Positioned(
                      left: 0,
                      width: constraints.maxWidth * (frames.length == 1 ? 1 : index / (frames.length - 1)),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDim, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Marcadores de quadro
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(frames.length, (i) {
                          final selected = i == index;
                          return GestureDetector(
                            onTap: () => controller.setFrame(i),
                            child: Container(
                              width: selected ? 12 : 6,
                              height: selected ? 12 : 6,
                              decoration: BoxDecoration(
                                color: selected
                                    ? (frames[i].isForecast ? AppColors.accent : AppColors.primary)
                                    : AppColors.textMuted.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: Colors.white, width: 1.5)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: index.toDouble(),
              min: 0,
              max: (frames.length - 1).toDouble().clamp(0, 10000),
              divisions: frames.length > 1 ? frames.length - 1 : null,
              onChanged: (v) => controller.setFrame(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveButton extends StatelessWidget {
  const _LiveButton({required this.controller, required this.enabled, this.active = false});

  final WeatherController controller;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.danger : AppColors.textMuted;
    return Semantics(
      button: true,
      label: 'Voltar para o AO VIVO',
      child: GestureDetector(
        onTap: enabled ? controller.goLive : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.danger.withValues(alpha: 0.18) : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                'LIVE',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 22,
            color: highlighted ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
