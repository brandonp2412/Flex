import 'package:flex/constants.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

/// A mock plan list tile previewing how [trailing] looks.
class PlanTrailingPreview extends StatelessWidget {
  final PlanTrailing trailing;

  const PlanTrailingPreview({super.key, required this.trailing});

  Widget _buildTrailing(BuildContext context) {
    return switch (trailing) {
      PlanTrailing.count => Text(
        formatDisplayNumber(context, 5, maxDigits: 0),
        style: const TextStyle(fontSize: 16),
      ),
      PlanTrailing.percent => Text(
        formatDisplayPercent(context, 5 / 6),
        style: const TextStyle(fontSize: 16),
      ),
      PlanTrailing.ratio => Text(
        '${formatDisplayNumber(context, 5, maxDigits: 0)} / ${formatDisplayNumber(context, 6, maxDigits: 0)}',
        style: const TextStyle(fontSize: 16),
      ),
      PlanTrailing.reorder => const Icon(Icons.drag_handle),
      PlanTrailing.none => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            localizedWeekday(context.l10n, 'Monday', abbreviated: true),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        title: Text(context.l10n.monday),
        subtitle: Text(context.l10n.examplePlanExercises),
        trailing: _buildTrailing(context),
      ),
    );
  }
}
