import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DesktopEditorSaveButton extends StatelessWidget {
  const DesktopEditorSaveButton({
    super.key,
    required this.onPressed,
    this.label,
  });

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 16),
    child: FilledButton.icon(
      key: const Key('desktop-editor-save'),
      onPressed: onPressed,
      icon: const Icon(Icons.save_rounded),
      label: Text(label ?? context.l10n.actionSave),
    ),
  );
}
