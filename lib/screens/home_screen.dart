import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/weather_layer.dart';
import '../services/geocoding_service.dart';
import '../state/weather_controller.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/conditions_panel.dart';
import '../widgets/layer_panel.dart';
import '../widgets/lightning_panel.dart';
import '../widgets/timeline_bar.dart';
import '../widgets/tornado_panel.dart';
import '../widgets/weather_map.dart';

/// Tela principal do OpenRadar: mapa em tela ampla com paineis flutuantes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _bottomPanel = 'layers'; // layers | alerts | tornado | lightning | conditions
  bool _showBottomPanel = true;
  List<GeoPlace> _searchResults = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherController>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPanel(String panel) {
    setState(() {
      if (_bottomPanel == panel && _showBottomPanel) {
        _showBottomPanel = false;
      } else {
        _bottomPanel = panel;
        _showBottomPanel = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WeatherController>();
    final isWide = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Mapa em tela ampla
          Positioned.fill(
            child: WeatherMapView(
              controller: controller,
              mapController: _mapController,
              onMapTap: (_) => setState(() => _searchFocus.unfocus()),
            ),
          ),

          // Barra superior: titulo, busca, status
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      controller: controller,
                      searchController: _searchController,
                      focusNode: _searchFocus,
                      results: _searchResults,
                      searching: _searching,
                      onSearch: _runSearch,
                      onClear: _clearSearch,
                      onSelect: _selectPlace,
                    ),
                    const SizedBox(height: 8),
                    _StatusStrip(controller: controller),
                  ],
                ),
              ),
            ),
          ),

          // Painel lateral (telas largas)
          if (isWide)
            Positioned(
              top: 118,
              right: 8,
              bottom: 150,
              width: 340,
              child: _SidePanels(
                controller: controller,
                panel: _bottomPanel,
                onSelect: (p) => setState(() => _bottomPanel = p),
              ),
            ),

          // Painel de condicoes (canto)
          if (!isWide && controller.focusPoint != null && _bottomPanel != 'conditions')
            Positioned(
              top: 118,
              left: 8,
              right: 8,
              child: ConditionsPanel(
                controller: controller,
                onClose: () => setState(() => controller.focusPoint == null),
              ),
            ),
          if (isWide && controller.focusPoint != null)
            Positioned(
              left: 8,
              top: 118,
              width: 340,
              child: ConditionsPanel(controller: controller),
            ),

          // Botoes flutuantes
          Positioned(
            right: 8,
            bottom: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Fab(
                  icon: Icons.my_location,
                  tooltip: 'Minha localizacao',
                  onTap: controller.locateUser,
                  loading: controller.locating,
                ),
                const SizedBox(height: 10),
                _Fab(
                  icon: Icons.refresh,
                  tooltip: 'Atualizar tudo agora',
                  onTap: () => controller.refreshAll(),
                ),
                const SizedBox(height: 10),
                _Fab(
                  icon: Icons.zoom_in,
                  tooltip: 'Aproximar',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 10),
                _Fab(
                  icon: Icons.zoom_out,
                  tooltip: 'Afastar',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
              ],
            ),
          ),

          // Barra inferior: navegacao + linha do tempo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showBottomPanel)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.42,
                            maxWidth: isWide ? 520 : double.infinity,
                          ),
                          child: _BottomPanelContent(
                            controller: controller,
                            panel: _bottomPanel,
                            onClose: () => setState(() => _showBottomPanel = false),
                          ),
                        ),
                      ),
                    RadarTimelineBar(controller: controller),
                    const SizedBox(height: 8),
                    _NavBar(
                      panel: _bottomPanel,
                      visible: _showBottomPanel,
                      onSelect: _openPanel,
                      alertCount: controller.activeAlerts.length,
                      tornadoCount: controller.tornadoWarnings.length,
                      strikeCount: controller.recentStrikes.length,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Aviso de localizacao negada
          if (controller.locationError != null)
            Positioned(
              top: 170,
              left: 20,
              right: 20,
              child: _Toast(text: controller.locationError!),
            ),
        ],
      ),
    );
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) return;
    setState(() => _searching = true);
    final controller = context.read<WeatherController>();
    final results = await controller.searchPlaces(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = const [];
    });
  }

  Future<void> _selectPlace(GeoPlace place) async {
    _searchFocus.unfocus();
    setState(() => _searchResults = const []);
    final controller = context.read<WeatherController>();
    await controller.goToPlace(place);
    _mapController.move(place.position, 9);
    setState(() => _bottomPanel = 'conditions');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.searchController,
    required this.focusNode,
    required this.results,
    required this.searching,
    required this.onSearch,
    required this.onClear,
    required this.onSelect,
  });

  final WeatherController controller;
  final TextEditingController searchController;
  final FocusNode focusNode;
  final List<GeoPlace> results;
  final bool searching;
  final Future<void> Function(String) onSearch;
  final VoidCallback onClear;
  final void Function(GeoPlace) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDim],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.radar, color: Color(0xFF04121A), size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OpenRadar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Monitoramento meteorologico ao vivo',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, height: 1.1),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar cidade (ex: Sao Paulo)',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: onClear,
                                visualDensity: VisualDensity.compact,
                              )
                            : null),
                    filled: true,
                    fillColor: AppColors.surfaceHigh.withValues(alpha: 0.7),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: results
                    .map((p) => InkWell(
                          onTap: () => onSelect(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 15, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.label,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.population > 0)
                                  Text(
                                    '${(p.population / 1000).round()}k',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Faixa de status: conexao, modo ao vivo e horarios de atualizacao.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final radarStatus = controller.status[LayerId.rainRadar];
    final radarUpdate = radarStatus?.lastUpdate;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _StatusPill(
            color: controller.online ? AppColors.success : AppColors.danger,
            icon: controller.online ? Icons.wifi : Icons.wifi_off,
            label: controller.online ? 'Conectado' : 'Sem conexao',
          ),
          const SizedBox(width: 8),
          _StatusPill(
            color: controller.isLiveFrame ? AppColors.danger : AppColors.warning,
            icon: controller.isLiveFrame ? Icons.fiber_manual_record : Icons.history,
            label: controller.isLiveFrame ? 'AO VIVO' : 'Historico',
          ),
          const Spacer(),
          if (radarUpdate != null)
            Text(
              'Radar ${Fmt.hourMinute(radarUpdate)}'
              '${radarStatus?.fromCache == true ? ' (cache)' : ''}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _BottomPanelContent extends StatelessWidget {
  const _BottomPanelContent({
    required this.controller,
    required this.panel,
    required this.onClose,
  });

  final WeatherController controller;
  final String panel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: switch (panel) {
        'alerts' => AlertsPanel(controller: controller),
        'tornado' => TornadoPanel(controller: controller),
        'lightning' => LightningPanel(controller: controller),
        'conditions' => ConditionsPanel(controller: controller),
        _ => LayerPanel(controller: controller),
      },
    );
  }
}

class _SidePanels extends StatelessWidget {
  const _SidePanels({required this.controller, required this.panel, required this.onSelect});

  final WeatherController controller;
  final String panel;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PanelTabs(panel: panel, onSelect: onSelect),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: switch (panel) {
              'alerts' => AlertsPanel(controller: controller),
              'tornado' => TornadoPanel(controller: controller),
              'lightning' => LightningPanel(controller: controller),
              _ => LayerPanel(controller: controller),
            },
          ),
        ),
      ],
    );
  }
}

class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.panel, required this.onSelect});

  final String panel;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(4),
      borderRadius: 12,
      child: Row(
        children: [
          _Tab(icon: Icons.layers, label: 'Camadas', active: panel == 'layers', onTap: () => onSelect('layers')),
          _Tab(icon: Icons.warning_amber, label: 'Alertas', active: panel == 'alerts', onTap: () => onSelect('alerts')),
          _Tab(icon: Icons.cyclone, label: 'Tornados', active: panel == 'tornado', onTap: () => onSelect('tornado')),
          _Tab(icon: Icons.bolt, label: 'Raios', active: panel == 'lightning', onTap: () => onSelect('lightning')),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Icon(icon, size: 17, color: active ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primary : AppColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.panel,
    required this.visible,
    required this.onSelect,
    required this.alertCount,
    required this.tornadoCount,
    required this.strikeCount,
  });

  final String panel;
  final bool visible;
  final void Function(String) onSelect;
  final int alertCount;
  final int tornadoCount;
  final int strikeCount;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.layers,
            label: 'Camadas',
            active: visible && panel == 'layers',
            onTap: () => onSelect('layers'),
          ),
          _NavItem(
            icon: Icons.warning_amber_rounded,
            label: 'Alertas',
            active: visible && panel == 'alerts',
            badge: alertCount,
            onTap: () => onSelect('alerts'),
          ),
          _NavItem(
            icon: Icons.cyclone,
            label: 'Tornados',
            active: visible && panel == 'tornado',
            badge: tornadoCount,
            danger: true,
            onTap: () => onSelect('tornado'),
          ),
          _NavItem(
            icon: Icons.bolt,
            label: 'Raios',
            active: visible && panel == 'lightning',
            badge: strikeCount,
            onTap: () => onSelect('lightning'),
          ),
          _NavItem(
            icon: Icons.thermostat,
            label: 'Condicoes',
            active: visible && panel == 'conditions',
            onTap: () => onSelect('conditions'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 19, color: color),
                  if (badge != null && badge! > 0)
                    Positioned(
                      right: -8,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: danger ? AppColors.danger : AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge! > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Color(0xFF04121A),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        elevation: 4,
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, size: 21, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
