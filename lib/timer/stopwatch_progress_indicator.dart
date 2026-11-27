import 'dart:math' as math;

import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/timer/time_with_milliseconds.dart';
import 'package:flex/timer/timer_progress_style.dart';
import 'package:flex/timer/timer_ring.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class StopwatchProgressIndicator extends StatefulWidget {
  final DateTime? startedAt;
  final Duration accumulated;
  final bool isRunning;
  final TimerState timerState;
  final VoidCallback onRestart;
  final Widget? trailingControl;

  const StopwatchProgressIndicator({
    super.key,
    required this.startedAt,
    required this.accumulated,
    required this.isRunning,
    required this.timerState,
    required this.onRestart,
    this.trailingControl,
  });

  @override
  State<StopwatchProgressIndicator> createState() =>
      _StopwatchProgressIndicatorState();
}

class _StopwatchProgressIndicatorState extends State<StopwatchProgressIndicator>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _ticker = createTicker((_) {
      if (widget.isRunning && mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
    if (widget.isRunning) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(StopwatchProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning ||
        widget.startedAt != oldWidget.startedAt ||
        widget.accumulated != oldWidget.accumulated) {
      _updateElapsed();
      if (widget.isRunning && !_ticker.isActive) {
        _ticker.start();
      } else if (!widget.isRunning && _ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _updateElapsed() {
    if (!widget.isRunning || widget.startedAt == null) {
      _elapsed = widget.accumulated;
    } else {
      _elapsed =
          widget.accumulated + DateTime.now().difference(widget.startedAt!);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double maxCircleSize = 280;
    final controlsHeight = widget.trailingControl == null ? 56.0 : 112.0;

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final started = _elapsed > Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? math.max(0.0, constraints.maxHeight - controlsHeight)
            : maxCircleSize;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxCircleSize;
        final circleSize = math.min(
          maxCircleSize,
          math.min(availableHeight, availableWidth),
        );
        const timeFontSize = timerFaceFontSize;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: circleSize,
              height: circleSize,
              child: RepaintBoundary(
                key: const ValueKey('stopwatch-ring'),
                child: TimerRing(
                  value:
                      (_elapsed.inMilliseconds /
                              const Duration(minutes: 5).inMilliseconds)
                          .clamp(0.0, 1.0),
                  circleSize: circleSize,
                  child: TimeWithMilliseconds(
                    time: _formatElapsed(_elapsed),
                    duration: _elapsed,
                    fontSize: timeFontSize,
                    color: onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: timerControlGap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (started)
                  TextButton.icon(
                    onPressed: widget.onRestart,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(context.l10n.actionRestart),
                  )
                else
                  TextButton(
                    onPressed: () => _addOneMinute(context),
                    child: Text(context.l10n.addOneMinute),
                  ),
                if (widget.trailingControl != null) ...[
                  const SizedBox(height: 8),
                  widget.trailingControl!,
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addOneMinute(BuildContext context) async {
    final settings = context.read<Setting>();
    if (defaultTargetPlatform != TargetPlatform.linux)
      await requestNotificationPermission();
    await widget.timerState.addOneMinute(
      settings.alarmSound,
      settings.vibrate,
      settings.enableSound,
      settings.keepRinging,
    );
  }

  String _formatElapsed(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
