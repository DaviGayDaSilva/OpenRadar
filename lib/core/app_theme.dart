import 'dart:ui';

import 'package:flutter/material.dart';

/// Paleta e tema visual do OpenRadar.
/// Inspirado em softwares profissionais de meteorologia: fundo escuro,
/// alto contraste e acentos ciano/ambar para leitura rapida de dados.
class AppColors {
  static const Color background = Color(0xFF070B12);
  static const Color surface = Color(0xFF101724);
  static const Color surfaceHigh = Color(0xFF182233);
  static const Color border = Color(0xFF243349);
  static const Color primary = Color(0xFF29D2E4);
  static const Color primaryDim = Color(0xFF17879A);
  static const Color accent = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF4D4D);
  static const Color warning = Color(0xFFFFC107);
  static const Color success = Color(0xFF31D68A);
  static const Color textPrimary = Color(0xFFE8EEF7);
  static const Color textSecondary = Color(0xFF8FA3BF);
  static const Color textMuted = Color(0xFF5D6E86);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Color(0xFF04121A),
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x3329D2E4),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryDim.withValues(alpha: 0.6)
              : AppColors.border,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    );
  }
}

/// Painel com efeito de vidro (glassmorphism) usado nos paineis flutuantes.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 16,
    this.opacity = 0.72,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double opacity;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border
                ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
