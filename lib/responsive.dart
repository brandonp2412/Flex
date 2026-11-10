import 'package:flutter/material.dart';

const double desktopBreakpoint = 900;
const double desktopMaxWidth = 1040;
const double wideMaxWidth = 1240;
const double dataMaxWidth = 1440;

/// Whether the current window should use Flex's desktop layout.
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

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

class ResponsiveSettingsList extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const ResponsiveSettingsList({
    super.key,
    required this.children,
    this.maxWidth = 800,
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
              horizontal: isDesktopLayout(context) ? 32 : 20,
            ),
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 116),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a native-feeling popup menu at a desktop secondary-click position.
Future<T?> showDesktopContextMenu<T>(
  BuildContext context,
  Offset globalPosition,
  List<PopupMenuEntry<T>> items,
) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      localPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
}
