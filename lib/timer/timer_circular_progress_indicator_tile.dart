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
import 'package:provider/provider.dart';

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
    const double maxCircleSize = 280;
    final controlsHeight = trailingControl == null ? 56.0 : 112.0;

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final remaining = timerState.timer.getRemaining();

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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: circleSize,
              height: circleSize,
              child: TimerRing(
                value: value,
                circleSize: circleSize,
                child: TimeWithMilliseconds(
                  time: generateTitleText(remaining),
                  duration: remaining,
                  fontSize: timerFaceFontSize,
                  color: onSurface,
                ),
              ),
            ),
            const SizedBox(height: timerControlGap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final settings = context.read<Setting>();
                    if (defaultTargetPlatform != TargetPlatform.linux)
                      await requestNotificationPermission();
                    await timerState.addOneMinute(
                      settings.alarmSound,
                      settings.vibrate,
                      settings.enableSound,
                      settings.keepRinging,
                    );
                  },
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
  }

  String generateTitleText(Duration remaining) {
    final minutes = (remaining.inMinutes).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
