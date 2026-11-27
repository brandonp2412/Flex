import 'package:flex/sets/workout_input.dart';
import 'package:flex/app_message.dart';
import 'package:flex/sets/workout_category_field.dart';
import 'package:flex/sets/workout_editor_fields.dart';
import 'package:flex/sets/workout_unit_field.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' hide Column, View;
import 'package:file_picker/file_picker.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/image_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/keyboard_close_observer.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Iterable<String> filterExerciseNameOptions(
  Iterable<String> options,
  String search,
) {
  final terms = search
      .toLowerCase()
      .split(' ')
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return options;

  return options.where((option) {
    final normalized = option.toLowerCase();
    for (final term in terms) {
      if (!normalized.contains(term)) return false;
    }
    return true;
  });
}

class EditSetPage extends StatefulWidget {
  final ExerciseSetView exerciseSet;

  const EditSetPage({super.key, required this.exerciseSet});

  @override
  createState() => _EditSetPageState();
}

class _EditSetPageState extends State<EditSetPage>
    with UnsavedChanges<EditSetPage> {
  final _orm = TextEditingController();
  final _body = TextEditingController();
  final _notes = TextEditingController();
  final _repsNode = FocusNode();
  final _distNode = FocusNode();
  final _input = WorkoutInput();
  final _key = GlobalKey<FormState>();

  var _categoryCtrl = TextEditingController();
  DateTime _created = DateTime.now().toLocal();
  TextEditingController? _nameCtrl;
  List<String> _options = [];
  int? restMs;
  String? _image;
  String? _category;
  bool _updatePending = false;

  late String _unit;
  late String _bodyUnit;
  late bool _cardio;
  late String _name;

  void onSelected(String option, bool showBodyWeight) async {
    markDirty();
    final last = await ExerciseSetQuery(db, exerciseName: option).firstOrNull();
    if (last == null) {
      final definition = await getExerciseByName(db, option);
      final categoryName = definition == null
          ? null
          : await getExerciseCategoryName(db, definition);
      if (!mounted) return;
      return setState(() {
        _name = option;
        if (definition != null) {
          _cardio = definition.kind == 'cardio';
          _unit = definition.displayUnit;
          _category = categoryName;
          _image = definition.image;
          restMs = definition.defaultRestDurationMs;
          if (categoryName != null && categoryName.isNotEmpty) {
            _categoryCtrl.text = categoryName;
          }
        }
      });
    }

    if (!mounted) return;
    if (showBodyWeight) {
      final bodyWeight = await getLatestBodyWeight(db);
      if (!mounted) return;
      updateFields(
        bodyWeight == null
            ? last
            : last.copyWith(
                bodyWeight: displayLoad(last.unit, bodyWeight.weightKg),
              ),
      );
    } else {
      updateFields(last.copyWith(bodyWeight: 0));
    }

    if (_cardio) {
      _distNode.requestFocus();
      selectAll(_input.distance);
    } else {
      _repsNode.requestFocus();
      selectAll(_input.reps);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBodyWeight = context.select<Setting, bool>(
      (settings) => settings.showBodyWeight,
    );

    return guardUnsavedChanges(
      child: editorScaffold(
        context,
        onSave: save,
        appBar: buildAppBar(),
        body: buildBody(showBodyWeight),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: Text(
        widget.exerciseSet.id > 0
            ? widget.exerciseSet.name
            : context.l10n.addSet,
      ),
      actions: [if (widget.exerciseSet.id > 0) buildDeleteButton()],
    );
  }

  Widget buildDeleteButton() {
    return IconButton(
      tooltip: context.l10n.deleteSet,
      icon: const Icon(Icons.delete),
      onPressed: () => showDeleteDialog(),
    );
  }

  Future<void> showDeleteDialog() async {
    final confirmed = await showAppConfirmation(
      context,
      title: context.l10n.confirmDelete,
      message: context.l10n.deleteSetConfirmation(widget.exerciseSet.name),
      actionLabel: context.l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await deleteExerciseSets(db, [widget.exerciseSet.id]);
    if (!mounted) return;
    allowPop = true;
    Navigator.pop(context);
  }

  Widget buildBody(bool showBodyWeight) {
    return EditorContent(
      child: Form(
        key: _key,
        child: Consumer<Setting>(
          builder: (context, settings, child) {
            final showUnits = settings.showUnits;
            final showCategories = settings.showCategories;
            final showNotes = settings.showNotes;
            final showImages = settings.showImages;

            return ListView(
              padding: editorListPadding(
                context,
                hasFab: !isDesktopLayout(context),
              ),
              children: [
                autocomplete(showBodyWeight),
                ...exerciseFields(),
                const SizedBox(height: 12.0),
                if (showBodyWeight) ...[
                  bodyFields(showBodyWeight),
                  const SizedBox(height: 12.0),
                ],
                if (showUnits) ...[
                  unitSelector(),
                  const SizedBox(height: 12.0),
                ],
                if (showCategories) ...[categorySelector()],
                if (showNotes) ...[notesField(), const SizedBox(height: 12.0)],
                dateSelector(),
                const SizedBox(height: 12),
                exerciseKindSelector(context, _cardio, (value) {
                  markDirty();
                  setState(() => _cardio = value!);
                }),
                if (showImages) ...[const SizedBox(height: 12), imageField()],
                if (isDesktopLayout(context)) ...[
                  const SizedBox(height: 24),
                  DesktopEditorSaveButton(onPressed: save),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> exerciseFields() {
    if (_cardio) return buildCardioFields();
    return buildStrengthFields();
  }

  List<Widget> buildStrengthFields() {
    return [
      const SizedBox(height: 12.0),
      buildRepsField(),
      const SizedBox(height: 12.0),
      buildWeightField(),
      const SizedBox(height: 12.0),
      if (isWeightUnit(_unit)) buildORMField(),
    ];
  }

  Widget buildRepsField() {
    return WorkoutNumberField(
      controller: _input.reps,
      focusNode: _repsNode,
      decoration: InputDecoration(labelText: context.l10n.repsLabel),
      step: 1,
      onChanged: (value) {
        markDirty();
        setORM();
      },
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => selectAll(_input.weight),
      validator: requiredNumberValidator(context),
    );
  }

  Widget buildWeightField() {
    return WorkoutNumberField(
      controller: _input.weight,
      decoration: InputDecoration(
        labelText: switch (_unit) {
          _ when isWeightUnit(_unit) => context.l10n.weightWithUnit(_unit),
          'kcal' => context.l10n.amountWithUnit(_unit),
          _ => context.l10n.distanceWithUnit(_unit),
        },
      ),
      step: weightStep(_name, _unit),
      onFieldSubmitted: (value) => save(),
      onChanged: (value) {
        markDirty();
        setORM();
      },
      validator: requiredNumberValidator(context),
    );
  }

  Widget buildORMField() {
    return TextField(
      controller: _orm,
      decoration: InputDecoration(labelText: context.l10n.oneRepMaxEstimate),
      enabled: false,
    );
  }

  List<Widget> buildCardioFields() {
    return [
      SizedBox(height: 12.0),
      buildDistanceField(),
      SizedBox(height: 12.0),
      duration(),
      SizedBox(height: 12.0),
      buildInclineField(),
    ];
  }

  Widget buildDistanceField() {
    if (isWeightUnit(_unit)) return buildWeightField();
    return WorkoutNumberField(
      controller: _input.distance,
      focusNode: _distNode,
      decoration: InputDecoration(
        labelText: _unit == 'kcal'
            ? context.l10n.amountWithUnit(_unit)
            : context.l10n.distanceWithUnit(_unit),
      ),
      onChanged: (_) => markDirty(),
      onFieldSubmitted: (_) => selectAll(_input.minutes),
      textInputAction: TextInputAction.next,
    );
  }

  Widget buildInclineField() => WorkoutNumberField(
    controller: _input.incline,
    decoration: InputDecoration(labelText: context.l10n.inclinePercent),
    onChanged: (_) => markDirty(),
    validator: wholeNumberValidator(context),
  );

  Widget bodyFields(bool showBodyWeight) {
    return Visibility(
      visible: showBodyWeight,
      child: WorkoutNumberField(
        controller: _body,
        decoration: InputDecoration(
          labelText: context.l10n.bodyWeightWithUnit(_bodyUnit),
        ),
        onChanged: (_) => markDirty(),
      ),
    );
  }

  Widget unitSelector() => WorkoutUnitField(
    unit: _unit,
    onChanged: (value) {
      markDirty();
      setState(() => _unit = value);
    },
  );

  Widget categorySelector() => WorkoutCategoryField(
    initial: widget.exerciseSet.category,
    onController: (controller) => _categoryCtrl = controller,
    onChanged: (value) {
      markDirty();
      setState(() => _category = value);
    },
  );

  Widget notesField() {
    return Selector<Setting, bool>(
      builder: (context, showNotes, child) => Visibility(
        visible: showNotes,
        child: TextField(
          maxLines: 3,
          decoration: InputDecoration(labelText: context.l10n.notesLabel),
          controller: _notes,
          onChanged: (_) => markDirty(),
        ),
      ),
      selector: (context, settings) => settings.showNotes,
    );
  }

  Widget dateSelector() =>
      workoutDateField(context, _created, selectDate, compact: true);

  Selector<Setting, bool> imageField() {
    return Selector<Setting, bool>(
      builder: (context, showImages, child) {
        return Visibility(
          visible: showImages,
          child: AppImageField(
            path: _image,
            onPick: pick,
            onRemove: () {
              markDirty();
              setState(() => _image = null);
            },
          ),
        );
      },
      selector: (context, settings) => settings.showImages,
    );
  }

  Widget duration() => _input.durationFields(
    context,
    onChanged: (_) => markDirty(),
    onMinutesSubmitted: (_) => selectAll(_input.seconds),
    onSecondsSubmitted: (_) => selectAll(_input.incline),
  );

  Autocomplete<String> autocomplete(bool showBodyWeight) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) =>
          filterExerciseNameOptions(_options, textEditingValue.text),
      onSelected: (option) => onSelected(option, showBodyWeight),
      initialValue: TextEditingValue(text: _name),
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController ctrl,
            FocusNode focusNode,
            VoidCallback onSubmit,
          ) {
            _nameCtrl = ctrl;
            return TextFormField(
              decoration: InputDecoration(labelText: context.l10n.nameLabel),
              controller: ctrl,
              textInputAction: TextInputAction.next,
              onTap: () {
                selectAll(ctrl);
              },
              focusNode: focusNode,
              onFieldSubmitted: (String value) {
                onSubmit();
              },
              onChanged: (value) {
                markDirty();
                setState(() {
                  _name = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty)
                  return context.l10n.requiredField;
                return null;
              },
            );
          },
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _repsNode.dispose();
    _orm.dispose();
    _body.dispose();
    _distNode.dispose();
    _notes.dispose();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_updatePending) return;
    _updatePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setORM();
    });
  }

  @override
  void initState() {
    super.initState();
    final settingUnit = context.read<Setting>().strengthUnit;
    _bodyUnit = switch (settingUnit) {
      'last-entry' when isWeightUnit(widget.exerciseSet.unit) =>
        widget.exerciseSet.unit,
      'last-entry' => 'kg',
      _ => settingUnit,
    };

    updateFields(widget.exerciseSet, formatOrm: false, rebuild: false);
    _created = widget.exerciseSet.created;

    getExerciseNames(db).then((names) {
      if (!mounted) return;
      _options = names;
    });
  }

  void pick() async {
    final result = await FilePicker.pickFiles();
    final path = (result.isEmpty ? null : result.single.path);
    if (path == null || !mounted) return;

    markDirty();
    setState(() {
      _image = path;
    });
  }

  Future<void> save() async {
    if (!_key.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();

    _category = _category?.trim();
    if (_category?.isEmpty ?? false) _category = null;

    final bodyValue = parseDisplayNumber(context, _body.text);
    final bodyWeightKg = bodyValue == null || bodyValue == 0
        ? null
        : loadKg(_bodyUnit, bodyValue);
    final exerciseSet = _input
        .apply(context, widget.exerciseSet)
        .copyWith(
          name: _name,
          unit: _unit,
          created: _created,
          bodyWeight: bodyValue,
          cardio: _cardio,
          restMs: Value(restMs),
          image: Value(_image),
          notes: Value(_notes.text),
          category: Value(_category),
        );

    final exercise = await syncExerciseDefinition(
      db,
      name: _name,
      cardio: _cardio,
      displayUnit: _unit,
      category: _category,
      image: _image,
      defaultRestDurationMs: restMs,
    );
    if (!mounted) return;

    final settings = context.read<Setting>();
    final messages = positiveReinforcementMessages(context.l10n);

    if (widget.exerciseSet.id > 0) {
      await updateExerciseSet(
        db,
        id: widget.exerciseSet.id,
        exerciseSet: exerciseSet,
        exerciseId: exercise.id,
        bodyWeightKg: bodyWeightKg,
      );
      if (!mounted) return;
      talker.info('Updated workout set');
      return _popAfterSave();
    }

    final inserted = await insertExerciseSet(
      db,
      exerciseSet: exerciseSet,
      exerciseId: exercise.id,
      bodyWeightKg: bodyWeightKg,
    );
    talker.info('Created workout set');

    if (settings.notifications) {
      final best = await isBestExerciseSet(db, inserted);
      if (best) {
        final random = Random();
        final randomMessage = messages[random.nextInt(messages.length)];
        if (mounted) showAppMessage(randomMessage);
      }
    }

    if (!settings.restTimers && mounted) {
      return _popAfterSave();
    }
    if (!mounted) return;
    final timer = context.read<TimerState>();
    timer.startTimer(
      _name,
      Duration(milliseconds: restMs ?? settings.timerDuration),
      settings.alarmSound,
      settings.vibrate,
      settings.enableSound,
      'history',
      settings.keepRinging,
    );
    if (!mounted) return;
    return _popAfterSave();
  }

  Future<void> _popAfterSave() async {
    final view = View.of(context);
    if (view.viewInsets.bottom > 0) {
      final closed = Completer<void>();
      final observer = KeyboardCloseObserver(view, closed);
      WidgetsBinding.instance.addObserver(observer);
      try {
        if (view.viewInsets.bottom > 0) {
          await closed.future.timeout(
            const Duration(milliseconds: 800),
            onTimeout: () {},
          );
        }
      } finally {
        WidgetsBinding.instance.removeObserver(observer);
      }
    }
    if (!mounted) return;
    allowPop = true;
    Navigator.of(context).pop();
  }

  void setORM() {
    final parsedReps = parseDisplayNumber(context, _input.reps.text);
    final parsedWeight = parseDisplayNumber(context, _input.weight.text);
    if (parsedReps == null || parsedWeight == null) return;
    final estimate = estimateOneRepMax(parsedWeight, parsedReps);
    _orm.text =
        "${formatDisplayNumber(context, estimate, minDigits: 2)} $_unit";
  }

  void updateFields(
    ExerciseSetView exerciseSet, {
    bool formatOrm = true,
    bool rebuild = true,
  }) {
    _nameCtrl?.text = exerciseSet.name;
    void updateState() {
      _category = exerciseSet.category;
      _image = exerciseSet.image;
      _name = exerciseSet.name;
      _unit = exerciseSet.unit;
      _cardio = exerciseSet.cardio;
      restMs = exerciseSet.restMs;
    }

    if (rebuild) {
      setState(updateState);
    } else {
      updateState();
    }

    _input.fill(exerciseSet, preserveZeroFields: true);
    if (formatOrm) setORM();
    if (exerciseSet.bodyWeight != 0) {
      final weightKg =
          loadKg(exerciseSet.unit, exerciseSet.bodyWeight) ??
          exerciseSet.bodyWeight;
      _body.text = toString(displayLoad(_bodyUnit, weightKg));
    }
    if (exerciseSet.category != null && exerciseSet.category!.isNotEmpty)
      _categoryCtrl.text = exerciseSet.category!;
    _notes.text = exerciseSet.notes ?? '';
  }

  Future<void> selectDate() async {
    final picked = await pickWorkoutDateTime(context, _created);
    if (picked == null || !mounted) return;
    markDirty();
    setState(() => _created = picked);
  }
}
