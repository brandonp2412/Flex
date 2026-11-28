import 'package:flutter/material.dart';

class StartPlanWideLayout extends StatelessWidget {
  const StartPlanWideLayout({
    super.key,
    required this.title,
    required this.fields,
    required this.exerciseList,
    this.sessionSets,
  });

  final String title;
  final List<Widget> fields;
  final Widget exerciseList;
  final Widget? sessionSets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panel = BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...fields,
                  if (sessionSets case final sets?) ...[
                    const SizedBox(height: 16),
                    sets,
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(decoration: panel, child: exerciseList),
          ),
        ),
      ],
    );
  }
}
