import 'package:file_picker/file_picker.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/app_fab.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/categories.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/responsive.dart';
import 'package:flex/image_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditGraphPage extends StatefulWidget {
  final String name;

  const EditGraphPage({required this.name, super.key});

  @override
  createState() => _EditGraphPageState();
}

class _EditGraphPageState extends State<EditGraphPage>
    with UnsavedChanges<EditGraphPage> {
  late final TextEditingController name = TextEditingController(
    text: widget.name,
  );
  final TextEditingController minutes = TextEditingController();
  final TextEditingController seconds = TextEditingController();
  final key = GlobalKey<FormState>();

  bool? cardio;
  int? _exerciseId;
  String? unit;
  String? image;
  String? category;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return guardUnsavedChanges(
      child: Scaffold(
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(context.l10n.updateAllNamed(widget.name.toLowerCase())),
        ),
        body: EditorContent(
          child: Form(
            key: key,
            child: ListView(
              padding: editorListPadding(context, hasFab: !desktop),
              children: [
                TextField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: context.l10n.newName),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => markDirty(),
                ),
                const SizedBox(height: 12.0),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: minutes,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.l10n.restMinutes,
                        ),
                        keyboardType: TextInputType.number,
                        onTap: () => selectAll(minutes),
                        onChanged: (_) => markDirty(),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          if (int.tryParse(value) == null)
                            return context.l10n.invalidNumber;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextFormField(
                        controller: seconds,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.l10n.restSeconds,
                        ),
                        keyboardType: TextInputType.number,
                        onTap: () {
                          selectAll(seconds);
                        },
                        onChanged: (_) => markDirty(),
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          if (int.tryParse(value) == null)
                            return context.l10n.invalidNumber;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Selector<Setting, bool>(
                  selector: (p0, settings) => settings.showCategories,
                  builder: (context, showCategories, child) {
                    if (!showCategories) return const SizedBox();
                    return StreamBuilder(
                      stream: getCategoriesStream(),
                      builder: (context, snapshot) {
                        final categories = <String>{
                          if (category != null && category!.isNotEmpty)
                            category!,
                          ...?snapshot.data,
                        }.toList();
                        return Column(
                          children: [
                            DropdownButtonFormField(
                              decoration: InputDecoration(
                                labelText: context.l10n.categoryLabel,
                              ),
                              initialValue: category,
                              items: categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                markDirty();
                                setState(() {
                                  category = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 12.0),
                          ],
                        );
                      },
                    );
                  },
                ),
                DropdownButtonFormField(
                  decoration: InputDecoration(
                    labelText: context.l10n.unitLabel,
                  ),
                  initialValue: unit,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("")),
                    ...strengthUnitMenuItems(context.l10n),
                    ...cardioUnitMenuItems(context.l10n),
                  ],
                  onChanged: (value) {
                    markDirty();
                    setState(() {
                      unit = value;
                    });
                  },
                ),
                if (cardio != null) ...[
                  const SizedBox(height: 12.0),
                  ListTile(
                    leading: cardio!
                        ? const Icon(Icons.sports_gymnastics)
                        : const Icon(Icons.fitness_center),
                    title: Text(
                      cardio! ? context.l10n.cardio : context.l10n.strength,
                    ),
                    onTap: () => _setCardio(!cardio!),
                    trailing: Switch(value: cardio!, onChanged: _setCardio),
                  ),
                  const SizedBox(height: 12.0),
                ] else
                  const SizedBox(height: 12.0),
                Selector<Setting, bool>(
                  builder: (context, showImages, child) {
                    return Visibility(
                      visible: showImages,
                      child: AppImageField(
                        path: image,
                        onPick: pick,
                        onRemove: () {
                          markDirty();
                          setState(() => image = null);
                        },
                      ),
                    );
                  },
                  selector: (context, settings) => settings.showImages,
                ),
                if (desktop) ...[
                  const SizedBox(height: 24),
                  DesktopEditorSaveButton(onPressed: save),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: desktop
            ? null
            : AppFab(
                onPressed: save,
                label: Text(context.l10n.actionSave),
                icon: const Icon(Icons.save),
              ),
      ),
    );
  }

  @override
  dispose() {
    name.dispose();
    minutes.dispose();
    seconds.dispose();
    super.dispose();
  }

  Future<void> doUpdate() async {
    Duration? duration;
    if (int.tryParse(minutes.text) != null && int.tryParse(minutes.text)! > 0 ||
        int.tryParse(seconds.text) != null && int.tryParse(seconds.text)! > 0) {
      duration = Duration(
        minutes: int.tryParse(minutes.text) ?? 0,
        seconds: int.tryParse(seconds.text) ?? 0,
      );
    }

    final exerciseId =
        _exerciseId ?? (await getExerciseByName(db, widget.name))?.id;
    if (exerciseId == null || cardio == null || unit == null) return;

    await updateExerciseDefinition(
      db,
      exerciseId: exerciseId,
      name: name.text.isEmpty ? widget.name : name.text,
      cardio: cardio!,
      displayUnit: unit!,
      defaultRestDurationMs: duration?.inMilliseconds,
      image: image,
      category: category,
    );
  }

  Future<int> getCount() => countGraphSets([name.text]);

  @override
  void initState() {
    super.initState();

    getExerciseByName(db, widget.name).then((exercise) async {
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
          final duration = Duration(
            milliseconds: exercise.defaultRestDurationMs!,
          );
          minutes.text = duration.inMinutes.toString();
          seconds.text = (duration.inSeconds % 60).toString();
        }
      });
    });
  }

  void pick() async {
    final result = await FilePicker.pickFiles();
    final path = (result.isEmpty ? null : result.single.path);
    if (path == null || !mounted) return;

    markDirty();
    setState(() {
      image = path;
    });
  }

  Future<bool> confirmUpdate(String title, String content) async {
    if (!mounted) return false;
    return showAppConfirmation(
      context,
      title: title,
      message: content,
      actionLabel: context.l10n.actionConfirm,
    );
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    final l10n = context.l10n;

    final count = await getCount();
    if (count > 0 && widget.name != name.text) {
      final confirmed = await confirmUpdate(
        l10n.updateConflict,
        l10n.updateConflictDescription(count),
      );
      if (!confirmed) return;
    }

    await doUpdate();

    if (!mounted) return;
    allowPop = true;
    Navigator.pop(context, name.text);
  }

  void _setCardio(bool value) {
    markDirty();
    setState(() {
      cardio = value;
      if (!value && unit != null && !isWeightUnit(unit!)) unit = 'kg';
    });
  }
}
