import 'package:flex/app_confirmation.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/material.dart';

/// Vertical space occupied by [AppSearch] when floated on top of a list: the
/// 56px search pill plus its 16px top padding. List views offset their content
/// by this amount so the first item clears the floating bar.
const double appSearchHeight = 72;

enum _AppSearchMenuAction {
  selectAll,
  merge,
  clearSelection,
  edit,
  share,
  weight,
  settings,
}

class AppSearch extends StatefulWidget {
  final Set<Object> controller;
  final TextEditingController? textController;
  final ValueChanged<String> onChange;
  final VoidCallback? onClearSelection;
  final VoidCallback onSelectAll;
  final Future<void> Function()? onMerge;
  final Future<void> Function() onDelete;
  final Future<void> Function() onEdit;
  final Future<void> Function() onShare;
  final Widget? filter;
  final String? confirmText;
  final Future<String> Function()? loadConfirmText;
  final String? hintText;

  const AppSearch({
    super.key,
    required this.controller,
    this.textController,
    this.onClearSelection,
    required this.onChange,
    required this.onSelectAll,
    this.onMerge,
    required this.onDelete,
    required this.onEdit,
    required this.onShare,
    this.filter,
    this.confirmText,
    this.loadConfirmText,
    this.hintText,
  });

  @override
  State<AppSearch> createState() => _AppSearchState();
}

class _AppSearchState extends State<AppSearch> {
  TextEditingController? _ownedController;
  TextEditingController get _ctrl =>
      widget.textController ?? (_ownedController ??= TextEditingController());
  final FocusNode _focusNode = FocusNode();

  void _clearSelection() {
    widget.controller.clear();
    final onClear = widget.onClearSelection;
    if (onClear == null) {
      widget.onChange(_ctrl.text);
    } else {
      onClear();
    }
  }

  Future<void> _handleMenuAction(_AppSearchMenuAction? action) async {
    if (action == null || !mounted) return;

    switch (action) {
      case _AppSearchMenuAction.selectAll:
        widget.onSelectAll();
        break;
      case _AppSearchMenuAction.merge:
        await widget.onMerge?.call();
        break;
      case _AppSearchMenuAction.clearSelection:
        _clearSelection();
        break;
      case _AppSearchMenuAction.edit:
        await widget.onEdit();
        break;
      case _AppSearchMenuAction.share:
        await widget.onShare();
        break;
      case _AppSearchMenuAction.weight:
        await Navigator.of(
          context,
        ).push(FlexPageRoute(builder: (context) => const WeightPage()));
        break;
      case _AppSearchMenuAction.settings:
        await Navigator.of(
          context,
        ).push(FlexPageRoute(builder: (context) => const SettingsPage()));
        break;
    }
  }

  _AppSearchMenuAction get _primaryAction =>
      widget.controller.length > 1 && widget.onMerge != null
      ? _AppSearchMenuAction.merge
      : _AppSearchMenuAction.selectAll;

  List<_AppSearchMenuAction> get _secondaryActions =>
      widget.controller.isNotEmpty
      ? [
          _AppSearchMenuAction.clearSelection,
          _AppSearchMenuAction.edit,
          _AppSearchMenuAction.share,
        ]
      : [_AppSearchMenuAction.weight, _AppSearchMenuAction.settings];

  (String, IconData, String) _actionDetails(
    BuildContext context,
    _AppSearchMenuAction action, {
    bool desktop = false,
  }) {
    final l10n = context.l10n;
    return switch (action) {
      _AppSearchMenuAction.selectAll => (
        l10n.selectAll,
        Icons.done_all,
        'select-all',
      ),
      _AppSearchMenuAction.merge => (
        l10n.mergeGraphs,
        Icons.merge_type_rounded,
        'merge-graphs',
      ),
      _AppSearchMenuAction.clearSelection => (
        l10n.clearSelection,
        Icons.deselect,
        'clear-selection',
      ),
      _AppSearchMenuAction.edit => (
        l10n.actionEdit,
        desktop ? Icons.edit_outlined : Icons.edit,
        'edit',
      ),
      _AppSearchMenuAction.share => (
        l10n.actionShare,
        desktop ? Icons.share_outlined : Icons.share,
        'share',
      ),
      _AppSearchMenuAction.weight => (
        l10n.weightLabel,
        desktop ? Icons.scale_outlined : Icons.scale,
        'weight',
      ),
      _AppSearchMenuAction.settings => (
        l10n.navSettings,
        desktop ? Icons.settings_outlined : Icons.settings,
        'search-settings',
      ),
    };
  }

  List<Widget> _desktopActions(BuildContext context, Widget trailingMain) => [
    if (widget.controller.isNotEmpty || widget.filter != null) trailingMain,
    for (final action in [..._secondaryActions, _primaryAction])
      Builder(
        builder: (context) {
          final (label, icon, key) = _actionDetails(
            context,
            action,
            desktop: true,
          );
          Future<void> onPressed() => _handleMenuAction(action);
          return action == _AppSearchMenuAction.merge
              ? FilledButton.icon(
                  key: Key('desktop-$key'),
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : IconButton(
                  key: Key('desktop-$key'),
                  tooltip: label,
                  icon: Icon(icon),
                  onPressed: onPressed,
                );
        },
      ),
  ];

  Widget _mobileMenu() => Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.more_vert),
      tooltip: context.l10n.showMenu,
      onPressed: () async {
        final button = context.findRenderObject() as RenderBox;
        final overlay =
            Navigator.of(context).overlay!.context.findRenderObject()
                as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        );
        final action = await showMenu<_AppSearchMenuAction>(
          context: context,
          position: position,
          items: [
            for (final action in [_primaryAction, ..._secondaryActions])
              PopupMenuItem(
                value: action,
                child: ListTile(
                  leading: Icon(_actionDetails(context, action).$2),
                  title: Text(_actionDetails(context, action).$1),
                ),
              ),
          ],
        );
        await _handleMenuAction(action);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sel = widget.controller;
    Widget trailingMain;

    if (sel.isNotEmpty) {
      trailingMain = IconButton(
        key: const ValueKey('deleteButton'),
        icon: const Icon(Icons.delete),
        tooltip: context.l10n.deleteSelected,
        onPressed: () async {
          final loadConfirmText = widget.loadConfirmText;
          final message = loadConfirmText == null
              ? widget.confirmText ??
                    context.l10n.deleteRecordsConfirmation(sel.length)
              : await loadConfirmText();
          if (!context.mounted) return;
          final confirmed = await showAppConfirmation(
            context,
            title: context.l10n.confirmDelete,
            message: message,
            actionLabel: context.l10n.actionDelete,
            destructive: true,
          );
          if (confirmed && mounted) await widget.onDelete();
        },
      );
    } else if (widget.filter != null) {
      trailingMain = KeyedSubtree(
        key: const ValueKey('filterWidget'),
        child: widget.filter!,
      );
    } else {
      trailingMain = const SizedBox.shrink(key: ValueKey('emptyWidget'));
    }

    final searchPadding = isDesktopLayout(context)
        ? const EdgeInsets.fromLTRB(24, 16, 24, 0)
        : const EdgeInsets.fromLTRB(16, 16, 16, 0);

    return ResponsiveContent(
      maxWidth: 760,
      desktopPadding: EdgeInsets.zero,
      mobilePadding: EdgeInsets.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusNode.requestFocus,
        child: Padding(
          padding: searchPadding,
          child: SearchBar(
            hintText: widget.hintText ?? context.l10n.searchHint,
            controller: _ctrl,
            focusNode: _focusNode,
            onTap: () => _focusNode.requestFocus(),
            padding: WidgetStateProperty.all(const EdgeInsets.only(right: 8.0)),
            textCapitalization: TextCapitalization.sentences,
            onChanged: widget.onChange,
            leading: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: sel.isEmpty && _ctrl.text.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Icon(Icons.search),
                    )
                  : IconButton(
                      tooltip: sel.isNotEmpty
                          ? context.l10n.clearSelection
                          : context.l10n.clearSearch,
                      onPressed: () {
                        if (sel.isNotEmpty) {
                          _clearSelection();
                          return;
                        }
                        _ctrl.clear();
                        widget.onChange('');
                      },
                      icon: const Icon(Icons.arrow_back),
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                    ),
            ),
            trailing: isDesktopLayout(context)
                ? _desktopActions(context, trailingMain)
                : [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: sel.isNotEmpty
                          ? Badge.count(
                              count: sel.length,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: trailingMain,
                            )
                          : trailingMain,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                    ),
                    _mobileMenu(),
                  ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ownedController?.dispose();
    super.dispose();
  }
}
