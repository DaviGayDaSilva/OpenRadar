import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/weather_layer.dart';
import '../state/weather_controller.dart';

/// Painel de raios ao vivo (rede Blitzortung).
class LightningPanel extends StatelessWidget {
  const LightningPanel({super.key, required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final recent = controller.recentStrikes;
    final total = controller.strikes.length;
    final connected = controller.lightningConnected;
    final status = controller.status[LayerId.lightning];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Color(0xFFFFD54F)),
              const SizedBox(width: 8),
              const Text(
                'RAIOS AO VIVO',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              _LiveDot(connected: connected),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Ultimos 15 min',
                  value: '${recent.length}',
                  color: const Color(0xFFFFD54F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Janela 45 min',
                  value: '$total',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? 'Conectado a rede Blitzortung  -  ultima deteccao ${Fmt.hourMinuteSecond(controller.lightning.lastMessageAt)}'
                : 'Reconectando a rede Blitzortung...',
            style: TextStyle(
              color: connected ? AppColors.success : AppColors.warning,
              fontSize: 10,
            ),
          ),
          if (status?.error != null)
            Text(
              status!.error!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          const Text(
            'Descargas detectadas em tempo real. Cobertura depende das estacoes da rede '
            'em cada regiao; areas sem deteccao nao significam ausencia de raios.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.danger : AppColors.textMuted;
    return Row(
      children: [
        _Pulse(color: color),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700, height: 1.0)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
        ],
      ),
    );
  }
}
