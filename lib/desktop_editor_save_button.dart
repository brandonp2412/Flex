import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DesktopEditorSaveButton extends StatelessWidget {
  const DesktopEditorSaveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 60,
    child: FilledButton.icon(
      key: const Key('desktop-editor-save'),
      onPressed: onPressed,
      icon: const Icon(Icons.save_rounded),
      label: Text(context.l10n.actionSave),
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
