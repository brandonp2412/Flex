import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class FlexSearchBar extends StatelessWidget {
  const FlexSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onChanged,
    this.onClearSelection,
    this.trailing,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClearSelection;
  final Iterable<Widget>? trailing;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => SearchBar(
    controller: controller,
    focusNode: focusNode,
    hintText: hintText,
    onTap: focusNode.requestFocus,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    textCapitalization: textCapitalization,
    onChanged: onChanged,
    leading: ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selection = onClearSelection;
        final empty = value.text.isEmpty;
        final icon = selection != null
            ? Icons.arrow_back
            : empty
            ? Icons.search
            : Icons.close_rounded;
        return SizedBox(
          width: 24,
          height: 48,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: selection != null
                ? context.l10n.clearSelection
                : empty
                ? context.l10n.searchHint
                : context.l10n.clearSearch,
            onPressed: () {
              if (selection != null) {
                selection();
              } else if (empty) {
                focusNode.requestFocus();
              } else {
                controller.clear();
                onChanged?.call('');
              }
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon)),
            ),
          ),
        );
      },
    ),
    trailing: trailing,
  );
}
