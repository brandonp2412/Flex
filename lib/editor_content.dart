import 'package:flex/app_fab.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class EditorContent extends StatelessWidget {
  const EditorContent({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ResponsiveContent(
    maxWidth: maxWidth,
    mobilePadding: const EdgeInsets.all(16),
    desktopPadding: const EdgeInsets.all(16),
    child: child,
  );
}

EdgeInsets editorListPadding(BuildContext context, {bool hasFab = true}) =>
    EdgeInsets.only(
      bottom: hasFab
          ? appFabBottomPadding(context) +
                56 +
                32 +
                MediaQuery.paddingOf(context).bottom
          : 24 + MediaQuery.paddingOf(context).bottom,
    );

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
