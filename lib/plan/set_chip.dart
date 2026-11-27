import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/set_summary.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flutter/material.dart';

class SetChip extends StatelessWidget {
  final ExerciseSetView? exerciseSet;
  final PreviousExerciseSet? previousSet;
  final ValueChanged<PreviousExerciseSet>? onPreviousTap;
  final int number;
  final bool best;
  final bool compact;

  const SetChip({
    super.key,
    this.exerciseSet,
    this.previousSet,
    this.onPreviousTap,
    required this.number,
    required this.best,
    required this.compact,
  });

  String _value(BuildContext context) {
    final set = exerciseSet;
    final previous = previousSet;
    return formatSetSummary(
      context,
      unitCode: set?.unit ?? previous!.unit,
      cardio: set?.cardio ?? previous!.cardio,
      weight: set?.weight ?? previous!.weight,
      reps: set?.reps ?? previous!.reps,
      distance: set?.distance ?? previous!.distance,
      duration: set?.duration ?? previous!.duration,
      incline: set == null ? previous!.incline : set.incline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSet = exerciseSet;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: switch (currentSet) {
          != null => () => Navigator.of(context).push(
            FlexPageRoute(
              builder: (context) => EditSetPage(exerciseSet: currentSet),
            ),
          ),
          _ when previousSet != null && onPreviousTap != null =>
            () => onPreviousTap!(previousSet!),
          _ => null,
        },
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                compact ? 10 : 8,
                previousSet == null ? 12 : 30,
                compact ? 10 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.setNumber(number),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (best) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  Text(_value(context), style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (previousSet != null)
              Positioned(
                top: compact ? 10 : 8,
                right: 10,
                child: Icon(
                  Icons.history_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
