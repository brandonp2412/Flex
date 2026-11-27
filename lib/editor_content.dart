import 'package:flex/app_fab.dart';
import 'package:flex/responsive.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/desktop_editor_save_button.dart';
import 'package:flutter/material.dart';

export 'package:flex/desktop_editor_save_button.dart';

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

Widget editorScaffold(
  BuildContext context, {
  required Widget title,
  List<Widget> actions = const [],
  required Widget body,
  required VoidCallback onSave,
}) => Scaffold(
  floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
  resizeToAvoidBottomInset: true,
  appBar: AppBar(
    title: title,
    actions: [
      ...actions,
      if (isDesktopLayout(context)) DesktopEditorSaveButton(onPressed: onSave),
    ],
  ),
  body: body,
  floatingActionButton: isDesktopLayout(context)
      ? null
      : AppFab(
          onPressed: onSave,
          label: Text(context.l10n.actionSave),
          icon: const Icon(Icons.save),
        ),
);

Widget editorFields(
  BuildContext context, {
  required List<Widget> children,
  GlobalKey<FormState>? formKey,
  double maxWidth = 720,
  bool formOutside = false,
}) {
  final desktop = isDesktopLayout(context);
  final list = ListView(
    padding: editorListPadding(context, hasFab: !desktop),
    children: children,
  );
  final content = EditorContent(
    maxWidth: maxWidth,
    child: formKey == null || formOutside
        ? list
        : Form(key: formKey, child: list),
  );
  return formOutside && formKey != null
      ? Form(key: formKey, child: content)
      : content;
}
