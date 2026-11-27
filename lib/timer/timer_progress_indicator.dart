import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimerProgressIndicator extends StatefulWidget {
  const TimerProgressIndicator({super.key});

  @override
  State<TimerProgressIndicator> createState() => _TimerProgressIndicatorState();
}

class _TimerProgressIndicatorState extends State<TimerProgressIndicator>
    with WidgetsBindingObserver {
  Duration? _lastDuration;
  DateTime? _lastTimestamp;
  GlobalKey? _animationKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _animationKey = GlobalKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerState>(
      builder: (context, timerState, child) {
        final duration = timerState.timer.total;
        final elapsed = timerState.timer.getElapsed();
        final remaining = timerState.timer.getRemaining();

        if (duration == Duration.zero || remaining == Duration.zero) {
          _lastDuration = null;
          _lastTimestamp = null;
          _animationKey = null;
          return const SizedBox.shrink();
        }

        final progress = elapsed.inMilliseconds / duration.inMilliseconds;

        final isNewTimer =
            _lastDuration != duration ||
            (_lastTimestamp != null &&
                timerState.timer.stamp
                        .difference(_lastTimestamp!)
                        .inSeconds
                        .abs() >
                    1);

        if (isNewTimer) {
          _lastDuration = duration;
          _lastTimestamp = timerState.timer.stamp;
          _animationKey = GlobalKey();
        }

        return Visibility(
          visible: true,
          child: TweenAnimationBuilder<double>(
            key: _animationKey,
            tween: Tween<double>(begin: 1.0 - progress, end: 0.0),
            duration: remaining,
            builder: (context, value, child) {
              return LinearProgressIndicator(value: value);
            },
          ),
        );
      },
    );
  }
}
