import 'package:flex/app_fab.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class StartPlanCompactLayout extends StatelessWidget {
  const StartPlanCompactLayout({
    super.key,
    required this.fields,
    required this.exerciseList,
  });

  final List<Widget> fields;
  final Widget exerciseList;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ...fields,
      Expanded(child: exerciseList),
    ],
  );
}

class StartPlanCompactDock extends StatelessWidget {
  const StartPlanCompactDock({
    super.key,
    required this.sessionSets,
    required this.onSave,
  });

  final Widget sessionSets;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('start-plan-floating-row'),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OverflowBox(
              alignment: Alignment.center,
              minHeight: 0,
              maxHeight: double.infinity,
              child: sessionSets,
            ),
          ),
        ),
        SizedBox(width: MediaQuery.viewInsetsOf(context).bottom > 0 ? 0 : 8),
        AppFab(
          onPressed: onSave,
          label: Text(context.l10n.actionSave),
          icon: const Icon(Icons.save),
          bottomPadding: 0,
        ),
      ],
    ),
  );
}
