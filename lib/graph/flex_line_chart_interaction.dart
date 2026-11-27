import 'package:drafter/drafter.dart';
import 'package:drafter/painting.dart';
import 'package:flex/graph/flex_line_chart_renderer.dart';
import 'package:flex/graph/flex_line_tooltip_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FlexLineChartInteraction extends StatefulWidget {
  final FlexLineChartRenderer renderer;
  final String Function(PlotMark mark) rowLabel;
  final ValueChanged<int>? onPointSelected;

  const FlexLineChartInteraction({
    super.key,
    required this.renderer,
    required this.rowLabel,
    this.onPointSelected,
  });

  @override
  State<FlexLineChartInteraction> createState() =>
      _FlexLineChartInteractionState();
}

class _FlexLineChartInteractionState extends State<FlexLineChartInteraction> {
  final ValueNotifier<int?> _activeIndex = ValueNotifier(null);

  void _activate(Offset position, ChartScene scene) {
    _activeIndex.value = ChartHitTest.nearestIndexAtX(scene, position.dx);
  }

  void _select(Offset position, ChartScene scene) {
    final callback = widget.onPointSelected;
    final index = ChartHitTest.nearestIndexAtX(scene, position.dx);
    if (callback != null && index != null) callback(index);
  }

  void _clear() {
    _activeIndex.value = null;
  }

  bool get _keepTooltipOnTapUp {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  void didUpdateWidget(FlexLineChartInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _activeIndex.value;
    if (index != null && !widget.renderer.hasIndex(index)) _clear();
  }

  @override
  void dispose() {
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? DrafterThemeColors.dark : DrafterThemeColors.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scene = widget.renderer.buildScene(size);

        return MouseRegion(
          onHover: (event) => _activate(event.localPosition, scene),
          onExit: (_) => _clear(),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _activate(event.localPosition, scene);
              _select(event.localPosition, scene);
            },
            onPointerUp: (event) {
              _activate(event.localPosition, scene);
              if (!_keepTooltipOnTapUp) _clear();
            },
            onPointerCancel: (_) => _clear(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) =>
                  _activate(details.localPosition, scene),
              onLongPressMoveUpdate: (details) =>
                  _activate(details.localPosition, scene),
              onLongPressEnd: (_) => _clear(),
              onLongPressCancel: _clear,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DrafterTheme(
                    colors: theme,
                    child: ChartCanvas(
                      renderer: widget.renderer,
                      animate: false,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: FlexLineTooltipPainter(
                            activeIndex: _activeIndex,
                            scene: scene,
                            theme: theme,
                            rowLabel: widget.rowLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
