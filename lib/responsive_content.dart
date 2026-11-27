import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

/// Constrains page content on wide windows while leaving mobile unconstrained.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry desktopPadding;
  final Alignment alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = desktopMaxWidth,
    this.mobilePadding = EdgeInsets.zero,
    this.desktopPadding = const EdgeInsets.symmetric(horizontal: 24),
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop ? maxWidth : double.infinity,
        ),
        child: Padding(
          padding: desktop ? desktopPadding : mobilePadding,
          child: child,
        ),
      ),
    );
  }
}
