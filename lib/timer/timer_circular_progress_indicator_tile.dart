import 'package:flex/timer/timer_face.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';

class TimerCircularProgressIndicatorTile extends StatelessWidget {
  final double value;
  final TimerState timerState;
  final Widget? trailingControl;

  const TimerCircularProgressIndicatorTile({
    super.key,
    required this.value,
    required this.timerState,
    this.trailingControl,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = timerState.timer.getRemaining();
    return TimerFace(
      value: value,
      duration: remaining,
      time: generateTitleText(remaining),
      timerState: timerState,
      trailingControl: trailingControl,
    );
  }

  String generateTitleText(Duration remaining) {
    final minutes = (remaining.inMinutes).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
