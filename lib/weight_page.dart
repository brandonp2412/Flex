import 'package:file_picker/file_picker.dart';
import 'package:flex/app_fab.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/image_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage>
    with UnsavedChanges<WeightPage> {
  final TextEditingController _ctrl = TextEditingController();
  BodyWeight? _previousWeight;
  bool _weightLoaded = false;
  String? _unit;
  String? _image;
  final _key = GlobalKey<FormState>();

  void pick() async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty || !mounted) return;

    markDirty();
    setState(() {
      _image = result.single.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayUnit = _unit ?? 'kg';
    final lastWeightText = !_weightLoaded
        ? ''
        : _previousWeight == null
        ? context.l10n.noWeightEnteredYet
        : '${formatDisplayNumber(context, displayBodyWeight(displayUnit, _previousWeight!.weightKg))} ${displayMeasurementUnit(context.l10n, displayUnit)}';

    return guardUnsavedChanges(
      child: Scaffold(
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(context.l10n.enterWeight)),
        body: Form(
          key: _key,
          child: EditorContent(
            child: ListView(
              padding: editorListPadding(context),
              children: [
                TextFormField(
                  controller: _ctrl,
                  onChanged: (_) => markDirty(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.weightLabel,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.requiredField;
                    }
                    if (parseDisplayNumber(context, value) == null) {
                      return context.l10n.invalidNumber;
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: context.l10n.unitLabel,
                  ),
                  initialValue: _unit,
                  items: strengthUnitMenuItems(context.l10n),
                  onChanged: (String? newValue) {
                    markDirty();
                    setState(() {
                      _unit = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(lastWeightText),
                  initialValue: lastWeightText,
                  decoration: InputDecoration(
                    labelText: context.l10n.previousWeight,
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 12),
                Selector<Setting, bool>(
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
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: AppFab(
          onPressed: () async {
            if (!_key.currentState!.validate()) return;

            final settings = context.read<Setting>();
            if (settings.strengthUnit != 'last-entry')
              _unit = settings.strengthUnit;

            final value = parseDisplayNumber(context, _ctrl.text)!;
            final unit = _unit ?? 'kg';
            final weightKg = toKg(unit, value);
            if (weightKg == null) return;
            await recordBodyWeight(
              db,
              timestamp: DateTime.now().toLocal(),
              weightKg: weightKg,
              photo: _image,
            );

            if (context.mounted) {
              allowPop = true;
              Navigator.pop(context);
            }
          },
          label: Text(context.l10n.actionSave),
          icon: const Icon(Icons.save),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<Setting>();

    getLatestBodyWeight(db).then((value) {
      if (!mounted) return;

      setState(() {
        _previousWeight = value;
        _weightLoaded = true;

        _unit = settings.strengthUnit == 'last-entry'
            ? 'kg'
            : settings.strengthUnit;
      });
    });
  }
}
