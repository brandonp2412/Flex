import 'package:flex/app_fab.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class SearchListScaffold extends StatelessWidget {
  const SearchListScaffold({
    super.key,
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.scroll,
    required this.body,
    this.showAdd = true,
  });

  final String title, addLabel;
  final VoidCallback onAdd;
  final ScrollController scroll;
  final Widget body;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      resizeToAvoidBottomInset: false,
      appBar: desktop
          ? AppBar(
              title: Text(title),
              actions: [
                if (showAdd)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(addLabel),
                    ),
                  ),
              ],
            )
          : null,
      body: body,
      floatingActionButton: desktop || !showAdd
          ? null
          : AppFab(
              onPressed: onAdd,
              label: Text(context.l10n.actionAdd),
              icon: const Icon(Icons.add),
              scroll: scroll,
            ),
    );
  }
}

Widget searchListBody({required Widget list, required Widget search}) => Stack(
  children: [
    Positioned.fill(child: list),
    Positioned(top: 0, left: 0, right: 0, child: search),
  ],
);
