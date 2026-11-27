import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerRing extends StatelessWidget {
  final double value;
  final double circleSize;
  final Widget child;

  const TimerRing({
    super.key,
    required this.value,
    required this.circleSize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const double strokeWidth = 8;
    const double dotSize = 16;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dotRadius = circleSize / 2;
    final angle = (-math.pi / 2) + (2 * math.pi * value);
    final dotX = dotRadius * math.cos(angle);
    final dotY = dotRadius * math.sin(angle);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: value > 0 ? 0.044 : 0),
                  blurRadius: 14,
                  blurStyle: BlurStyle.outer,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              strokeCap: StrokeCap.round,
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
        ),
        if (value > 0)
          Transform.translate(
            offset: Offset(dotX, dotY),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.22),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}
