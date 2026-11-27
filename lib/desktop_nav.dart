import 'package:flex/bottom_nav.dart';
import 'package:flex/desktop_nav_item.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DesktopNav extends StatelessWidget {
  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final void Function(BuildContext, String)? onSecondaryTap;
  final VoidCallback onSettingsTap;
  final bool settingsSelected;

  const DesktopNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.onSettingsTap,
    this.settingsSelected = false,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .35),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center_rounded, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.appTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...tabs
                  .asMap()
                  .entries
                  .where((entry) => entry.value != 'SettingsPage')
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DesktopNavItem(
                        key: Key(entry.value),
                        icon: BottomNav.iconForTab(entry.value),
                        label: BottomNav.labelForTab(context, entry.value),
                        selected:
                            !settingsSelected && entry.key == currentIndex,
                        onTap: () => onTap(entry.key),
                        onSecondaryTap: onSecondaryTap == null
                            ? null
                            : () => onSecondaryTap!(context, entry.value),
                      ),
                    ),
                  ),
              const Spacer(),
              Divider(color: colors.outlineVariant.withValues(alpha: .35)),
              const SizedBox(height: 8),
              DesktopNavItem(
                key: const Key('desktop-settings'),
                icon: Icons.settings_rounded,
                label: context.l10n.navSettings,
                selected: settingsSelected,
                onTap: onSettingsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
