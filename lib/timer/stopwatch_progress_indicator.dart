import 'package:flex/timer/timer_face.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  Widget build(BuildContext context) => TimerFace(
    value: (_elapsed.inMilliseconds / const Duration(minutes: 5).inMilliseconds)
        .clamp(0.0, 1.0),
    duration: _elapsed,
    time: _formatElapsed(_elapsed),
    timerState: widget.timerState,
    trailingControl: widget.trailingControl,
    onRestart: _elapsed > Duration.zero ? widget.onRestart : null,
    stopwatch: true,
  );

  String _formatElapsed(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
