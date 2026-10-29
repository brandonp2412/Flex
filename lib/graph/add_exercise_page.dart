import 'package:file_picker/file_picker.dart';
import 'package:flex/app_fab.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/responsive.dart';
import 'package:flex/image_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddExercisePage extends StatefulWidget {
  final String? name;

  const AddExercisePage({super.key, this.name});

  @override
  createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<AddExercisePage>
    with UnsavedChanges<AddExercisePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _cardio = false;

  late var settings = context.watch<Setting>();
  late String _unit = settings.strengthUnit == 'last-entry'
      ? 'kg'
      : settings.strengthUnit;
  String? _image;
  final _key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.name != null) _nameCtrl.text = widget.name!;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    settings = context.watch<Setting>();

    return guardUnsavedChanges(
      child: Scaffold(
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(context.l10n.addExercise)),
        body: EditorContent(
          child: Form(
            key: _key,
            child: ListView(
              padding: editorListPadding(context, hasFab: !desktop),
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.nameLabel,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  onChanged: (_) => markDirty(),
                  validator: (value) => value?.isNotEmpty == true
                      ? null
                      : context.l10n.requiredField,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_unit),
                  decoration: InputDecoration(
                    labelText: context.l10n.unitLabel,
                  ),
                  initialValue: _unit,
                  items: [
                    ...strengthUnitMenuItems(context.l10n),
                    ...cardioUnitMenuItems(context.l10n),
                  ],
                  onChanged: (String? newValue) {
                    markDirty();
                    setState(() {
                      _unit = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    _cardio ? context.l10n.cardio : context.l10n.strength,
                  ),
                  leading: _cardio
                      ? const Icon(Icons.sports_gymnastics)
                      : const Icon(Icons.fitness_center),
                  onTap: () => _setCardio(!_cardio),
                  trailing: Switch(value: _cardio, onChanged: _setCardio),
                ),
                Visibility(
                  visible: settings.showImages,
                  child: AppImageField(
                    path: _image,
                    onPick: pick,
                    onRemove: () {
                      markDirty();
                      setState(() => _image = null);
                    },
                  ),
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
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setCardio(bool value) {
    markDirty();
    setState(() {
      _cardio = value;
      if (value && isWeightUnit(_unit)) {
        _unit = settings.cardioUnit == 'last-entry'
            ? 'km'
            : settings.cardioUnit;
      } else if (!value && !isWeightUnit(_unit)) {
        _unit = settings.strengthUnit == 'last-entry'
            ? 'kg'
            : settings.strengthUnit;
      }
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

    if (settings.strengthUnit != 'last-entry' && !_cardio)
      _unit = settings.strengthUnit;
    else if (settings.cardioUnit != 'last-entry' && _cardio)
      _unit = settings.cardioUnit;

    final exercise = await createExerciseDefinition(
      db,
      name: _nameCtrl.text,
      cardio: _cardio,
      displayUnit: _unit,
      image: _image,
    );
    talker.info('Created exercise definition');
    if (!mounted) return;

    allowPop = true;
    Navigator.pop(context, exercise);
  }
}
