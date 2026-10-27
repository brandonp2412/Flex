import 'package:flex/app_fab.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class EditorContent extends StatelessWidget {
  const EditorContent({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ResponsiveContent(
    maxWidth: maxWidth,
    mobilePadding: const EdgeInsets.all(16),
    desktopPadding: const EdgeInsets.all(16),
    child: child,
  );
}

EdgeInsets editorListPadding(BuildContext context, {bool hasFab = true}) =>
    EdgeInsets.only(
      bottom: hasFab
          ? appFabBottomPadding(context) +
                56 +
                32 +
                MediaQuery.paddingOf(context).bottom
          : 24 + MediaQuery.paddingOf(context).bottom,
    );
