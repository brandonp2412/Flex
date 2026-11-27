import 'package:flex/sets/workout_input.dart';
import 'package:flex/sets/workout_category_field.dart';
import 'package:flex/sets/workout_editor_fields.dart';
import 'package:flex/sets/workout_unit_field.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'package:drift/drift.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditSetsPage extends StatefulWidget {
  final List<int> ids;

  const EditSetsPage({super.key, required this.ids});

  @override
  createState() => _EditSetsPageState();
}

class _EditSetsPageState extends State<EditSetsPage>
    with UnsavedChanges<EditSetsPage> {
  final _body = TextEditingController();
  final _name = TextEditingController();
  final _input = WorkoutInput();
  final _key = GlobalKey<FormState>();

  String? _unit;
  DateTime? _created;
  bool? _cardio;
  int? _restMs;
  String? _category;
  String? _oldNames;
  String? _oldReps;
  String? _oldWeights;
  String? _oldBody;
  String? _oldCreated;
  String? _oldDist;
  String? _oldMin;
  String? _oldSec;
  String? _oldInc;
  String? _oldCat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return guardUnsavedChanges(
      child: editorScaffold(
        context,
        appBar: AppBar(
          title: Text(l10n.editSets(widget.ids.length)),
          actions: [
            IconButton(
              tooltip: l10n.deleteSelected,
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showAppConfirmation(
                  context,
                  title: l10n.confirmDelete,
                  message: l10n.deleteEntriesConfirmation(widget.ids.length),
                  actionLabel: l10n.actionDelete,
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;
                await deleteExerciseSets(db, widget.ids);
                if (!context.mounted) return;
                allowPop = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
        onSave: save,
        body: editorFields(
          context,
          onSave: save,
          formKey: _key,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: _oldNames,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => markDirty(),
            ),
            const SizedBox(height: 12),
            exerciseKindSelector(context, _cardio, (value) {
              markDirty();
              setState(() => _cardio = value);
            }, allowEmpty: true),
            const SizedBox(height: 12),
            if (_cardio == true) ...[
              if (isWeightUnit(_unit))
                _input.field(
                  context,
                  WorkoutMetric.weight,
                  hint: _oldWeights,
                  onChanged: (_) => markDirty(),
                )
              else
                _input.field(
                  context,
                  WorkoutMetric.distance,
                  hint: _oldDist,
                  onChanged: (_) => markDirty(),
                ),
              const SizedBox(height: 12),
              _input.durationFields(
                context,
                minutesHint: _oldMin,
                secondsHint: _oldSec,
                onChanged: (_) => markDirty(),
              ),
              const SizedBox(height: 12),
              _input.field(
                context,
                WorkoutMetric.incline,
                hint: _oldInc,
                onChanged: (_) => markDirty(),
              ),
            ],
            if (_cardio == false || _cardio == null) ...[
              _input.field(
                context,
                WorkoutMetric.reps,
                hint: _oldReps,
                onChanged: (_) => markDirty(),
              ),
              const SizedBox(height: 12),
              _input.field(
                context,
                WorkoutMetric.weight,
                label: switch (_unit) {
                  null => l10n.weightLabel,
                  _ when isWeightUnit(_unit) => l10n.weightLabel,
                  'kcal' => l10n.amountWithUnit(_unit!),
                  _ => l10n.distanceWithUnit(_unit!),
                },
                hint: _oldWeights,
                onChanged: (_) => markDirty(),
              ),
            ],
            const SizedBox(height: 12),
            Selector<Setting, bool>(
              builder: (context, showBodyWeight, child) => Visibility(
                visible: showBodyWeight,
                child: WorkoutNumberField(
                  controller: _body,
                  decoration: InputDecoration(
                    labelText: l10n.bodyWeightLabel,
                    hintText: _oldBody,
                  ),
                  onChanged: (_) => markDirty(),
                ),
              ),
              selector: (context, settings) => settings.showBodyWeight,
            ),
            const SizedBox(height: 12),
            WorkoutUnitField(
              unit: _unit,
              onChanged: (value) {
                markDirty();
                setState(() => _unit = value);
              },
            ),
            const SizedBox(height: 12),
            WorkoutCategoryField(
              initial: _category,
              hint: _oldCat,
              keepHidden: true,
              onChanged: (value) {
                markDirty();
                setState(() => _category = value);
              },
            ),
            workoutDateField(context, _created, _selectDate, hint: _oldCreated),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _body.dispose();
    _name.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<Setting>();

    ExerciseSetQuery(db, ids: widget.ids).get().then((allSets) {
      final exerciseSets = allSets.take(3).toList();
      if (!mounted || exerciseSets.isEmpty) return;
      setState(() {
        _cardio = exerciseSets.first.cardio;
        final units = exerciseSets
            .map((exerciseSet) => exerciseSet.unit)
            .toSet();
        _unit = units.length == 1 ? units.single : null;
        String? hint(Object? Function(ExerciseSetView) value) {
          final text = exerciseSets.map(value).nonNulls.join(', ');
          return text.isEmpty ? null : text;
        }

        _oldNames = hint((set) => set.name);
        _oldReps = hint((set) => set.reps);
        _oldWeights = hint((set) => set.weight);
        _oldBody = hint((set) => set.bodyWeight);
        _oldCreated = hint(
          (set) =>
              formatWorkoutDate(context, set.created, settings.longDateFormat),
        );
        _oldDist = hint((set) => set.distance);
        _oldMin = hint((set) => set.duration.floor());
        _oldSec = hint((set) => ((set.duration * 60) % 60).floor());
        _oldInc = hint((set) => set.incline);
        _oldCat = hint((set) => set.category);
      });
    });
  }

  Future<void> save() async {
    if (!_key.currentState!.validate()) return;

    _category = _category?.trim();
    if (_category?.isEmpty ?? false) _category = null;
    final bodyWeight = _body.text.isEmpty
        ? null
        : parseDisplayNumber(context, _body.text);
    final applyInput = _input.snapshot(context, partial: true);
    final preferredStrengthUnit = context.read<Setting>().strengthUnit;
    final selected = await ExerciseSetQuery(db, ids: widget.ids).get();

    final changesExercise =
        _name.text.isNotEmpty ||
        _unit != null ||
        _cardio != null ||
        _restMs != null ||
        _category != null;

    for (final original in selected) {
      final name = _name.text.isNotEmpty ? _name.text : original.name;
      final unit = _unit ?? original.unit;
      final cardio = _cardio ?? original.cardio;
      final restMs = _restMs ?? original.restMs;
      final category = _category ?? original.category;

      final exercise = changesExercise
          ? await syncExerciseDefinition(
              db,
              name: name,
              cardio: cardio,
              displayUnit: unit,
              category: category,
              image: original.image,
              defaultRestDurationMs: restMs,
            )
          : await getExerciseByName(db, original.name);
      if (exercise == null) continue;

      final originalBodyWeightKg = original.bodyWeight == 0
          ? null
          : loadKg(original.unit, original.bodyWeight) ?? original.bodyWeight;
      final bodyUnit = switch (preferredStrengthUnit) {
        _ when isWeightUnit(unit) => unit,
        'last-entry' => 'kg',
        _ => preferredStrengthUnit,
      };
      final bodyWeightKg = bodyWeight == null
          ? originalBodyWeightKg
          : loadKg(bodyUnit, bodyWeight);
      final updated = applyInput(original).copyWith(
        name: name,
        unit: unit,
        created: _created ?? original.created,
        cardio: cardio,
        restMs: Value(restMs),
        bodyWeight: bodyWeight ?? original.bodyWeight,
        category: Value(category),
      );

      await updateExerciseSet(
        db,
        id: original.id,
        exerciseSet: updated,
        exerciseId: exercise.id,
        bodyWeightKg: bodyWeightKg,
      );
    }

    if (!mounted) return;
    allowPop = true;
    Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final picked = await pickWorkoutDateTime(context, _created);
    if (picked == null || !mounted) return;
    markDirty();
    setState(() => _created = picked);
  }
}
