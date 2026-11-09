import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isDesktopPlatform =>
    !kIsWeb &&
    {
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform);

/// Material route semantics on mobile, but truly instant transitions on desktop.
class FlexPageRoute<T> extends MaterialPageRoute<T> {
  FlexPageRoute({
    required super.builder,
    super.settings,
    super.requestFocus,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
    this.snapshotOnPop = false,
  });

  final bool snapshotOnPop;
  final SnapshotController _popSnapshotController = SnapshotController();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = super.buildPage(context, animation, secondaryAnimation);
    if (!snapshotOnPop || isDesktopPlatform) return page;
    return SnapshotWidget(
      controller: _popSnapshotController,
      mode: SnapshotMode.permissive,
      child: page,
    );
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (popped && snapshotOnPop && !isDesktopPlatform) {
      _popSnapshotController.allowSnapshotting = true;
    }
    return popped;
  }

  @override
  void dispose() {
    _popSnapshotController.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration =>
      isDesktopPlatform ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      isDesktopPlatform ? Duration.zero : super.reverseTransitionDuration;
}
