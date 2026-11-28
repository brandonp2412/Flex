import 'package:flutter/material.dart';

class MadeInNewZealandBadge extends StatelessWidget {
  const MadeInNewZealandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      key: const Key('made-in-new-zealand-branding'),
      decoration: ShapeDecoration(
        color: colors.surfaceContainerLow,
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                key: const Key('new-zealand-outline'),
                size: const Size.square(24),
                painter: _NewZealandOutlinePainter(colors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Made in New Zealand',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewZealandOutlinePainter extends CustomPainter {
  const _NewZealandOutlinePainter(this.color);

  final Color color;

  // Natural Earth 1:50m public-domain coastline, simplified for 24dp.
  static final _outline = Path()
    ..moveTo(12.77, 12.73)
    ..lineTo(13.82, 12.13)
    ..lineTo(13.63, 12.71)
    ..lineTo(13.89, 12.25)
    ..lineTo(14.27, 12.29)
    ..lineTo(13.94, 12.66)
    ..lineTo(14.36, 12.43)
    ..lineTo(13.98, 12.98)
    ..lineTo(14.25, 13.50)
    ..lineTo(12.90, 15.57)
    ..lineTo(12.15, 16.06)
    ..lineTo(12.02, 16.39)
    ..lineTo(12.72, 16.74)
    ..lineTo(12.71, 17.07)
    ..lineTo(11.40, 16.78)
    ..lineTo(11.59, 17.11)
    ..lineTo(10.40, 17.73)
    ..lineTo(9.81, 20.42)
    ..lineTo(8.00, 21.67)
    ..lineTo(6.79, 21.65)
    ..lineTo(5.72, 20.88)
    ..lineTo(4.70, 20.96)
    ..lineTo(4.93, 20.56)
    ..lineTo(4.60, 20.70)
    ..lineTo(4.39, 20.35)
    ..lineTo(5.04, 20.15)
    ..lineTo(4.71, 19.74)
    ..lineTo(4.87, 19.48)
    ..lineTo(5.23, 19.65)
    ..lineTo(5.28, 18.90)
    ..lineTo(6.19, 18.40)
    ..lineTo(6.88, 17.33)
    ..lineTo(7.79, 17.14)
    ..lineTo(10.06, 15.14)
    ..lineTo(10.14, 15.38)
    ..lineTo(10.71, 13.59)
    ..lineTo(11.29, 13.16)
    ..lineTo(11.54, 12.17)
    ..lineTo(12.17, 11.45)
    ..lineTo(12.55, 11.45)
    ..lineTo(12.25, 11.70)
    ..close()
    ..moveTo(12.96, 2.10)
    ..lineTo(14.29, 2.62)
    ..lineTo(14.90, 4.40)
    ..lineTo(14.80, 5.29)
    ..lineTo(15.84, 5.89)
    ..lineTo(15.73, 4.68)
    ..lineTo(16.55, 6.64)
    ..lineTo(18.03, 7.22)
    ..lineTo(18.96, 6.49)
    ..lineTo(19.62, 6.72)
    ..lineTo(18.83, 9.31)
    ..lineTo(18.34, 9.03)
    ..lineTo(17.78, 9.28)
    ..lineTo(17.48, 10.85)
    ..lineTo(16.39, 12.61)
    ..lineTo(15.54, 13.28)
    ..lineTo(14.98, 12.63)
    ..lineTo(14.69, 12.74)
    ..lineTo(15.36, 11.62)
    ..lineTo(15.35, 10.77)
    ..lineTo(13.59, 9.44)
    ..lineTo(14.64, 8.55)
    ..lineTo(15.06, 6.90)
    ..lineTo(14.63, 5.72)
    ..lineTo(15.06, 5.70)
    ..lineTo(14.49, 5.46)
    ..lineTo(14.13, 4.71)
    ..lineTo(14.40, 4.89)
    ..lineTo(14.38, 4.28)
    ..lineTo(13.78, 3.73)
    ..lineTo(13.96, 4.48)
    ..lineTo(13.14, 3.12)
    ..lineTo(13.42, 2.74)
    ..lineTo(13.02, 2.95)
    ..lineTo(12.25, 1.29)
    ..lineTo(12.68, 1.25)
    ..close()
    ..moveTo(6.49, 22.08)
    ..lineTo(6.61, 22.43)
    ..lineTo(5.70, 22.74)
    ..lineTo(6.03, 21.81)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      _outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NewZealandOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
