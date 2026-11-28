import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class ResponsiveSettingsList extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final double bottomPadding;

  const ResponsiveSettingsList({
    super.key,
    required this.children,
    this.maxWidth = settingsMaxWidth,
    this.bottomPadding = 116,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          minLeadingWidth: 24,
          horizontalTitleGap: 16,
          minVerticalPadding: 12,
          iconColor: colors.primary,
          titleTextStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        iconTheme: theme.iconTheme.copyWith(size: 22),
        dividerTheme: DividerThemeData(
          color: colors.outlineVariant.withValues(alpha: 0.35),
          thickness: 1,
          space: 1,
        ),
        expansionTileTheme: ExpansionTileThemeData(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: colors.primary,
          textColor: colors.primary,
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktopLayout(context) ? 32 : pagePadding,
            ),
            child: ListView(
              padding: EdgeInsets.only(top: 12, bottom: bottomPadding),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
