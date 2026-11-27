import 'dart:math';

import 'package:flex/bottom_nav.dart';
import 'package:flutter/material.dart';

/// Keep Save and its previews above *both* the bottom dock and Android IME.
/// Using a single location throughout the keyboard animation avoids the
/// 80dp teleport caused by swapping FAB locations at the first nonzero inset.
class StartPlanDockLocation extends FloatingActionButtonLocation {
  const StartPlanDockLocation(this.bottomViewPadding);

  final double bottomViewPadding;

  @override
  bool operator ==(Object other) =>
      other is StartPlanDockLocation &&
      other.bottomViewPadding == bottomViewPadding;

  @override
  int get hashCode => Object.hash(StartPlanDockLocation, bottomViewPadding);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final centered = FloatingActionButtonLocation.centerFloat.getOffset(
      geometry,
    );
    final dockTop =
        geometry.scaffoldSize.height - bottomViewPadding - bottomNavHeight;
    // The IME inset starts at the window bottom, but our route's Scaffold
    // already excludes the persistent bottom gesture-navigation safe area.
    final keyboardTop = geometry.contentBottom + bottomViewPadding;
    final bottom = min(dockTop, keyboardTop) - 16;
    return Offset(
      centered.dx,
      bottom - geometry.floatingActionButtonSize.height,
    );
  }
}
