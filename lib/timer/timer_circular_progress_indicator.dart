import 'package:flex/timer/timer_circular_progress_indicator_tile.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimerCircularProgressIndicator extends StatefulWidget {
  final Widget? trailingControl;

  const TimerCircularProgressIndicator({super.key, this.trailingControl});
  @override
  State<TimerCircularProgressIndicator> createState() =>
      _TimerCircularProgressIndicatorState();
}

class _TimerCircularProgressIndicatorState
    extends State<TimerCircularProgressIndicator> {
  // Start true so the idle state never triggers the spurious stopping animation
  // on the very first build (when no timer has run yet).
  bool _stopping = true;
  double _lastValue = 0;

  // Animation key — replaced only at true phase transitions detected in
  // didChangeDependencies, which runs before build in the same frame. This
  // ensures the new render object is laid out before the semantics pass,
  // avoiding the '!parentDataDirty' / '_needsLayout' assertions.
  Key _animationKey = UniqueKey();

  // Phase-transition tracking (updated in didChangeDependencies).
  bool _prevStarting = false;
  bool _prevActive = false;
  Duration? _prevDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final timerState = Provider.of<TimerState>(context);
    final duration = timerState.timer.total;
    final remaining = timerState.timer.getRemaining();
    final isActive = duration > Duration.zero && remaining > Duration.zero;

    var needNewKey = false;

    if (timerState.starting && !_prevStarting && isActive) {
      // Entering the brief start animation (idle/stopped → starting).
      needNewKey = true;
    } else if (!timerState.starting && _prevStarting && isActive) {
      // Start animation finished; entering the running phase.
      needNewKey = true;
    } else if (isActive && !_prevActive) {
      // Timer became active without a start animation (first use or no starting flag).
      needNewKey = true;
      _stopping = false;
    } else if (isActive && duration != _prevDuration) {
      // Duration changed while running (e.g. +1 minute).
      needNewKey = true;
    } else if (!isActive && _prevActive && !_stopping) {
      // Timer just expired; queue the stopping animation.
      needNewKey = true;
    }

    if (needNewKey) _animationKey = UniqueKey();

    _prevStarting = timerState.starting;
    _prevActive = isActive;
    _prevDuration = duration;
  }

  @override
  Widget build(BuildContext context) {
    final timerState = Provider.of<TimerState>(context);
    final duration = timerState.timer.total;
    final elapsed = timerState.timer.getElapsed();
    final remaining = timerState.timer.getRemaining();

    // Phase 1 — brief entering animation (0 → current position in 300 ms).
    if (duration > Duration.zero &&
        remaining > Duration.zero &&
        timerState.starting) {
      return TweenAnimationBuilder(
        key: _animationKey,
        tween: Tween<double>(
          begin: 0,
          end: 1 - (elapsed.inMilliseconds / duration.inMilliseconds),
        ),
        duration: const Duration(milliseconds: 300),
        onEnd: () {
          timerState.setStarting(false);
        },
        builder: (context, value, child) => TimerCircularProgressIndicatorTile(
          value: value,
          timerState: timerState,
          trailingControl: widget.trailingControl,
        ),
      );
    }

    // Phase 2 — timer running (animate from current position to 0).
    if (duration > Duration.zero && remaining > Duration.zero) {
      _lastValue = 1 - (elapsed.inMilliseconds / duration.inMilliseconds);
      // Allow the stopping animation to play once this phase has been entered.
      _stopping = false;
      return TweenAnimationBuilder(
        key: _animationKey,
        tween: Tween<double>(begin: _lastValue, end: 0),
        duration: remaining,
        builder: (context, value, child) => TimerCircularProgressIndicatorTile(
          value: value,
          timerState: timerState,
          trailingControl: widget.trailingControl,
        ),
      );
    }

    // Phase 3 — stopping animation (current position → 0 in 300 ms).
    // Only fires after the timer was actually running (_stopping == false).
    if (!timerState.starting && !_stopping) {
      _stopping = true;
      return TweenAnimationBuilder(
        key: _animationKey,
        tween: Tween<double>(begin: _lastValue, end: 0),
        duration: const Duration(milliseconds: 300),
        onEnd: () {
          setState(() {
            _stopping = false;
          });
          timerState.setStarting(true);
        },
        builder: (context, value, child) => TimerCircularProgressIndicatorTile(
          value: value,
          timerState: timerState,
          trailingControl: widget.trailingControl,
        ),
      );
    }

    return TimerCircularProgressIndicatorTile(
      value: 0,
      timerState: timerState,
      trailingControl: widget.trailingControl,
    );
  }
}
