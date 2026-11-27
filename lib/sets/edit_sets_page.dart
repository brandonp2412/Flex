import 'package:flex/sets/workout_input.dart';
import 'package:flex/sets/workout_category_field.dart';
import 'package:flex/sets/workout_editor_fields.dart';
import 'package:flex/sets/workout_unit_field.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/bulk_edit_exercise_sets.dart';
import 'package:flex/logging.dart';
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
  bool _kindChanged = false;
  bool _unitChanged = false;
  bool _saving = false;
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
        onSave: save,
        body: editorFields(
          context,
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
              setState(() {
                _kindChanged = true;
                _cardio = value;
              });
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
                setState(() {
                  _unitChanged = true;
                  _unit = value;
                });
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

    ExerciseSetQuery(db, ids: widget.ids, limit: 3).get().then((exerciseSets) {
      if (!mounted || exerciseSets.isEmpty) return;
      setState(() {
        if (!_kindChanged) _cardio = exerciseSets.first.cardio;
        final units = exerciseSets
            .map((exerciseSet) => exerciseSet.unit)
            .toSet();
        if (!_unitChanged) _unit = units.length == 1 ? units.single : null;
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
    if (_saving || !_key.currentState!.validate()) return;
    _saving = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(content: LinearProgressIndicator()),
      ),
    );
    navigator.push(route);
    try {
      final name = _name.text.trim();
      final category = _category?.trim();
      final preferredStrengthUnit = context.read<Setting>().strengthUnit;
      final cardio = _cardio == true;
      await bulkEditExerciseSets(
        db,
        widget.ids,
        name: name.isEmpty ? null : name,
        unit: _unitChanged ? _unit : null,
        cardio: _kindChanged ? _cardio : null,
        category: category == null || category.isEmpty ? null : category,
        timestamp: _created,
        reps: cardio ? null : parseDisplayNumber(context, _input.reps.text),
        weight: !cardio || isWeightUnit(_unit)
            ? parseDisplayNumber(context, _input.weight.text)
            : null,
        distance: cardio && !isWeightUnit(_unit)
            ? parseDisplayNumber(context, _input.distance.text)
            : null,
        durationMs: cardio && !_input.durationInput.isEmpty
            ? _input.durationInput.value.inMilliseconds
            : null,
        incline: cardio
            ? parseDisplayNumber(context, _input.incline.text)
            : null,
        bodyWeight: parseDisplayNumber(context, _body.text),
        preferredStrengthUnit: preferredStrengthUnit,
      );
      if (route.isActive) navigator.removeRoute(route);
      if (!mounted) return;
      allowPop = true;
      Navigator.pop(context);
    } catch (error, stackTrace) {
      talker.handle(error, stackTrace, 'Bulk edit failed');
      if (route.isActive) navigator.removeRoute(route);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.unexpectedError)));
    } finally {
      _saving = false;
    }
  }

  Future<void> _selectDate() async {
    final picked = await pickWorkoutDateTime(context, _created);
    if (picked == null || !mounted) return;
    markDirty();
    setState(() => _created = picked);
  }
}
