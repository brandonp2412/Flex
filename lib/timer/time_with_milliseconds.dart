import 'package:flutter/material.dart';

class TimeWithMilliseconds extends StatelessWidget {
  final String time;
  final Duration duration;
  final double fontSize;
  final Color color;

  const TimeWithMilliseconds({
    super.key,
    required this.time,
    required this.duration,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final milliseconds = duration.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            time,
            maxLines: 1,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          '.$milliseconds',
          style: TextStyle(
            fontSize: fontSize * 0.32,
            color: color.withValues(alpha: 0.45),
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
            height: 0.9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
