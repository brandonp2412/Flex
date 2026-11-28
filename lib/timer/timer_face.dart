import 'dart:math' as math;

import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/timer/time_with_milliseconds.dart';
import 'package:flex/timer/timer_progress_style.dart';
import 'package:flex/timer/timer_ring.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/utils.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimerFace extends StatelessWidget {
  const TimerFace({
    super.key,
    required this.value,
    required this.duration,
    required this.time,
    required this.timerState,
    this.trailingControl,
    this.onRestart,
    this.stopwatch = false,
  });

  final double value;
  final Duration duration;
  final String time;
  final TimerState timerState;
  final Widget? trailingControl;
  final VoidCallback? onRestart;
  final bool stopwatch;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxSize = isDesktopLayout(context) ? 380.0 : 280.0;
      final controlsHeight = trailingControl == null ? 56.0 : 112.0;
      final size = math.min(
        maxSize,
        math.min(
          constraints.maxHeight.isFinite
              ? math.max(0.0, constraints.maxHeight - controlsHeight)
              : maxSize,
          constraints.maxWidth.isFinite ? constraints.maxWidth : maxSize,
        ),
      );
      final ring = TimerRing(
        value: value,
        circleSize: size,
        child: TimeWithMilliseconds(
          time: time,
          duration: duration,
          fontSize: timerFaceFontSize * size / 280,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: stopwatch
                ? RepaintBoundary(
                    key: const ValueKey('stopwatch-ring'),
                    child: ring,
                  )
                : ring,
          ),
          const SizedBox(height: timerControlGap),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRestart != null)
                TextButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(context.l10n.actionRestart),
                )
              else
                TextButton(
                  onPressed: () => _addOneMinute(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(96, 48),
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  child: Text(context.l10n.addOneMinute),
                ),
              if (trailingControl != null) ...[
                const SizedBox(height: 8),
                trailingControl!,
              ],
            ],
          ),
        ],
      );
    },
  );

  Future<void> _addOneMinute(BuildContext context) async {
    final settings = context.read<Setting>();
    if (defaultTargetPlatform != TargetPlatform.linux)
      await requestNotificationPermission();
    await timerState.addOneMinute(settings);
  }
}
