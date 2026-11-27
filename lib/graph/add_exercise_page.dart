import 'package:file_picker/file_picker.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/editor_content.dart';
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
  bool _saving = false;
  String? _duplicateName;

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
    settings = context.watch<Setting>();

    return guardUnsavedChanges(
      child: editorScaffold(
        context,
        appBar: AppBar(title: Text(context.l10n.addExercise)),
        onSave: save,
        body: editorFields(
          context,
          onSave: save,
          formKey: _key,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: context.l10n.nameLabel),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              onChanged: (_) {
                markDirty();
                if (_duplicateName != null) {
                  _duplicateName = null;
                  _key.currentState!.validate();
                }
              },
              validator: (value) {
                if (value?.trim().isNotEmpty != true) {
                  return context.l10n.requiredField;
                }
                if (value!.trim().toLowerCase() == _duplicateName) {
                  return context.l10n.exerciseAlreadyExists;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_unit),
              decoration: InputDecoration(labelText: context.l10n.unitLabel),
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
          ],
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
    if (_saving || !_key.currentState!.validate()) return;

    if (settings.strengthUnit != 'last-entry' && !_cardio)
      _unit = settings.strengthUnit;
    else if (settings.cardioUnit != 'last-entry' && _cardio)
      _unit = settings.cardioUnit;

    final name = _nameCtrl.text.trim();
    _saving = true;
    final Exercise? exercise;
    try {
      exercise = await db.transaction(() async {
        final existing = await db.select(db.exercises).get();
        if (existing.any(
          (row) => row.name.trim().toLowerCase() == name.toLowerCase(),
        )) {
          return null;
        }
        return createExerciseDefinition(
          db,
          name: name,
          cardio: _cardio,
          displayUnit: _unit,
          image: _image,
        );
      });
    } finally {
      _saving = false;
    }
    if (!mounted) return;
    if (exercise == null) {
      _duplicateName = name.toLowerCase();
      _key.currentState!.validate();
      return;
    }
    talker.info('Created exercise definition');

    allowPop = true;
    Navigator.pop(context, exercise);
  }
}
