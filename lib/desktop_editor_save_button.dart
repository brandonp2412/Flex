import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DesktopEditorSaveButton extends StatelessWidget {
  const DesktopEditorSaveButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon = Icons.save_rounded,
    this.actionKey = const Key('desktop-editor-save'),
  });

  final VoidCallback? onPressed;
  final String? label;
  final IconData icon;
  final Key actionKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 16),
    child: FilledButton.icon(
      key: actionKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label ?? context.l10n.actionSave),
    ),
  );
}
