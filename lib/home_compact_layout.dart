import 'package:flex/bottom_nav.dart';
import 'package:flutter/material.dart';

class HomeCompactLayout extends StatelessWidget {
  const HomeCompactLayout({
    super.key,
    required this.tabs,
    required this.controller,
    required this.pages,
    required this.scrollable,
    required this.onHideTab,
    required this.progress,
  });

  final List<String> tabs;
  final TabController controller;
  final List<Widget> pages;
  final bool scrollable;
  final void Function(BuildContext, String) onHideTab;
  final Widget progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      TabBarView(
        controller: controller,
        physics: scrollable
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      if (scrollable)
        for (final leftEdge in [true, false])
          Positioned(
            left: leftEdge ? 0 : null,
            right: leftEdge ? null : 0,
            top: 0,
            bottom: 0,
            width: 30,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (_) {},
            ),
          ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: ValueListenableBuilder(
          valueListenable: controller.animation!,
          builder: (context, value, child) => BottomNav(
            tabs: tabs,
            currentIndex: value.round(),
            onTap: controller.animateTo,
            onLongPress: onHideTab,
          ),
        ),
      ),
      progress,
    ],
  );
}
