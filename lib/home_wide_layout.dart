import 'package:flex/desktop_nav.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flutter/material.dart';

class HomeWideLayout extends StatelessWidget {
  const HomeWideLayout({
    super.key,
    required this.tabs,
    required this.tabController,
    required this.pageController,
    required this.pages,
    required this.onSelectTab,
    required this.onHideTab,
    required this.onOpenSettings,
    required this.settingsOpen,
    required this.nestedSettingsTabs,
    required this.progress,
  });

  final List<String> tabs;
  final TabController tabController;
  final PageController pageController;
  final List<Widget> pages;
  final ValueChanged<int> onSelectTab;
  final void Function(BuildContext, String) onHideTab;
  final VoidCallback onOpenSettings;
  final bool settingsOpen;
  final Set<String> nestedSettingsTabs;
  final Widget progress;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ListenableBuilder(
        listenable: tabController,
        builder: (context, child) {
          final index = tabController.index.clamp(0, tabs.length - 1);
          final tab = tabs[index];
          return DesktopNav(
            tabs: tabs,
            currentIndex: index,
            onTap: onSelectTab,
            onSecondaryTap: onHideTab,
            onSettingsTap: onOpenSettings,
            settingsSelected:
                settingsOpen ||
                nestedSettingsTabs.contains(tab) ||
                tab == 'SettingsPage',
          );
        },
      ),
      Expanded(
        child: settingsOpen
            ? const SettingsPage()
            : Stack(
                children: [
                  PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      if (tabController.index != index) {
                        tabController.index = index;
                      }
                    },
                    children: pages,
                  ),
                  progress,
                ],
              ),
      ),
    ],
  );
}
