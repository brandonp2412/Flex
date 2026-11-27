import 'package:flex/duration_input.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/categories.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/image_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flex/sets/workout_editor_fields.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'package:flex/logging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExerciseEditorPage extends StatefulWidget {
  const ExerciseEditorPage.add({super.key, this.name}) : editing = false;
  const ExerciseEditorPage.edit({super.key, required String this.name})
    : editing = true;

  final String? name;
  final bool editing;

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

class _ExerciseEditorPageState extends State<ExerciseEditorPage>
    with UnsavedChanges<ExerciseEditorPage> {
  late final name = TextEditingController(text: widget.name);
  final rest = DurationInput();
  final key = GlobalKey<FormState>();
  bool? cardio;
  int? _exerciseId;
  String? unit;
  String? image;
  String? category;
  String? _duplicateName;
  bool _saving = false;
  bool get editing => widget.editing;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();
    final l10n = context.l10n;
    return guardUnsavedChanges(
      child: editorScaffold(
        context,
        title: Text(
          editing
              ? l10n.updateAllNamed(widget.name!.toLowerCase())
              : l10n.addExercise,
        ),
        onSave: save,
        body: editorFields(
          context,
          formKey: key,
          children: [
            TextFormField(
              controller: name,
              textInputAction: editing ? TextInputAction.next : null,
              decoration: InputDecoration(
                labelText: editing ? l10n.newName : l10n.nameLabel,
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: !editing,
              onChanged: (_) {
                markDirty();
                if (_duplicateName != null) {
                  _duplicateName = null;
                  key.currentState!.validate();
                }
              },
              validator: editing
                  ? null
                  : (value) {
                      if (value?.trim().isNotEmpty != true)
                        return l10n.requiredField;
                      if (value!.trim().toLowerCase() == _duplicateName)
                        return l10n.exerciseAlreadyExists;
                      return null;
                    },
            ),
            const SizedBox(height: 12),
            if (editing) ...[
              Row(
                children: [
                  for (final (controller, label) in [
                    (rest.minutes, l10n.restMinutes),
                    (rest.seconds, l10n.restSeconds),
                  ]) ...[
                    if (controller == rest.seconds) const SizedBox(width: 8),
                    Expanded(
                      child: WorkoutNumberField(
                        controller: controller,
                        decoration: InputDecoration(labelText: label),
                        integer: true,
                        onChanged: (_) => markDirty(),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (settings.showCategories) _categoryField(),
            ],
            DropdownButtonFormField<String>(
              key: editing ? null : ValueKey(unit),
              decoration: InputDecoration(labelText: l10n.unitLabel),
              initialValue: unit,
              items: [
                if (editing)
                  const DropdownMenuItem(value: null, child: Text('')),
                ...workoutUnitItems(context),
              ],
              onChanged: (value) {
                markDirty();
                setState(() => unit = value);
              },
            ),
            if (cardio != null) ...[
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  cardio! ? Icons.sports_gymnastics : Icons.fitness_center,
                ),
                title: Text(cardio! ? l10n.cardio : l10n.strength),
                onTap: () => _setCardio(!cardio!),
                trailing: Switch(value: cardio!, onChanged: _setCardio),
              ),
            ],
            if (editing) const SizedBox(height: 12),
            Visibility(
              visible: settings.showImages,
              child: AppImageField(
                path: image,
                onPick: pick,
                onRemove: () {
                  markDirty();
                  setState(() => image = null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryField() => StreamBuilder(
    stream: getCategoriesStream(),
    builder: (context, snapshot) => Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.l10n.categoryLabel),
          initialValue: category,
          items: [
            for (final value in {
              if (category?.isNotEmpty == true) category!,
              ...?snapshot.data,
            })
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) {
            markDirty();
            setState(() => category = value);
          },
        ),
        const SizedBox(height: 12),
      ],
    ),
  );

  @override
  void dispose() {
    name.dispose();
    rest.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!editing) {
      final settings = context.read<Setting>();
      cardio = false;
      unit = settings.strengthUnit == 'last-entry'
          ? 'kg'
          : settings.strengthUnit;
      return;
    }
    getExerciseByName(db, widget.name!).then((exercise) async {
      if (exercise == null || !mounted) return;
      final categoryName = await getExerciseCategoryName(db, exercise);
      if (!mounted) return;
      setState(() {
        _exerciseId = exercise.id;
        image = exercise.image;
        cardio = exercise.kind == 'cardio';
        unit = exercise.displayUnit;
        category = categoryName;
        if (exercise.defaultRestDurationMs != null) {
          rest.fill(Duration(milliseconds: exercise.defaultRestDurationMs!));
        }
      });
    });
  }

  void _setCardio(bool value) {
    final settings = context.read<Setting>();
    markDirty();
    setState(() {
      cardio = value;
      if (editing) {
        if (!value && unit != null && !isWeightUnit(unit!)) unit = 'kg';
      } else if (value && isWeightUnit(unit)) {
        unit = settings.cardioUnit == 'last-entry' ? 'km' : settings.cardioUnit;
      } else if (!value && !isWeightUnit(unit)) {
        unit = settings.strengthUnit == 'last-entry'
            ? 'kg'
            : settings.strengthUnit;
      }
    });
  }

  void pick() async {
    final result = await FilePicker.pickFiles();
    final path = result.isEmpty ? null : result.single.path;
    if (path == null || !mounted) return;
    markDirty();
    setState(() => image = path);
  }

  Future<void> save() async {
    if (_saving || !key.currentState!.validate()) return;
    _saving = true;
    try {
      if (editing) {
        await _update();
      } else {
        await _create();
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _update() async {
    final l10n = context.l10n;
    final count = await countExerciseSetsForExercises(db, [name.text]);
    if (!mounted) return;
    if (count > 0 && widget.name != name.text) {
      final confirmed = await showAppConfirmation(
        context,
        title: l10n.updateConflict,
        message: l10n.updateConflictDescription(count),
        actionLabel: l10n.actionConfirm,
      );
      if (!confirmed) return;
    }
    final exerciseId =
        _exerciseId ?? (await getExerciseByName(db, widget.name!))?.id;
    if (exerciseId != null && cardio != null && unit != null) {
      await updateExerciseDefinition(
        db,
        exerciseId: exerciseId,
        name: name.text.isEmpty ? widget.name! : name.text,
        cardio: cardio!,
        displayUnit: unit!,
        defaultRestDurationMs: rest.positiveMilliseconds,
        image: image,
        category: category,
      );
    }
    if (!mounted) return;
    allowPop = true;
    Navigator.pop(context, name.text);
  }

  Future<void> _create() async {
    final settings = context.read<Setting>();
    if (settings.strengthUnit != 'last-entry' && !cardio!) {
      unit = settings.strengthUnit;
    } else if (settings.cardioUnit != 'last-entry' && cardio!) {
      unit = settings.cardioUnit;
    }
    final candidate = name.text.trim();
    final exercise = await db.transaction(() async {
      final existing = await db.select(db.exercises).get();
      if (existing.any(
        (row) => row.name.trim().toLowerCase() == candidate.toLowerCase(),
      ))
        return null;
      return createExerciseDefinition(
        db,
        name: candidate,
        cardio: cardio!,
        displayUnit: unit!,
        image: image,
      );
    });
    if (!mounted) return;
    if (exercise == null) {
      _duplicateName = candidate.toLowerCase();
      key.currentState!.validate();
      return;
    }
    talker.info('Created exercise definition');
    allowPop = true;
    Navigator.pop(context, exercise);
  }
}
