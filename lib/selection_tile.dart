import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class SelectionTile extends StatelessWidget {
  const SelectionTile({
    super.key,
    required this.selected,
    required this.selectionActive,
    required this.onSelect,
    required this.onOpen,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onSecondaryTapDown,
    this.desktopPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 5,
    ),
    this.desktopVerticalPadding = 9,
    this.grouped = false,
  });

  final bool selected, selectionActive, grouped;
  final VoidCallback onSelect, onOpen;
  final Widget title;
  final Widget? leading, subtitle, trailing;
  final GestureTapDownCallback? onSecondaryTapDown;
  final EdgeInsets desktopPadding;
  final double desktopVerticalPadding;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    final card = desktop && !grouped;
    final colors = Theme.of(context).colorScheme;
    final tile = Material(
      color: selected
          ? colors.primary.withValues(alpha: .18)
          : card
          ? colors.surfaceContainerLow
          : Colors.transparent,
      borderRadius: card ? BorderRadius.circular(16) : null,
      clipBehavior: card ? Clip.antiAlias : Clip.none,
      child: ListTile(
        contentPadding: card
            ? EdgeInsets.symmetric(
                horizontal: 20,
                vertical: desktopVerticalPadding,
              )
            : null,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: selectionActive ? onSelect : onOpen,
        onLongPress: desktop ? null : onSelect,
      ),
    );
    if (!desktop) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: grouped ? tile : Padding(padding: desktopPadding, child: tile),
    );
  }
}

enum EditDeleteAction { edit, delete }

Future<EditDeleteAction?> showEditDeleteMenu(
  BuildContext context,
  Offset position, {
  bool edit = true,
  bool delete = true,
}) => showDesktopContextMenu<EditDeleteAction>(context, position, [
  if (edit)
    PopupMenuItem(
      value: EditDeleteAction.edit,
      child: ListTile(
        leading: const Icon(Icons.edit_outlined),
        title: Text(context.l10n.actionEdit),
      ),
    ),
  if (delete)
    PopupMenuItem(
      value: EditDeleteAction.delete,
      child: ListTile(
        leading: const Icon(Icons.delete_outline),
        title: Text(context.l10n.actionDelete),
      ),
    ),
]);
