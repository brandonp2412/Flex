import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlanExerciseSettingsDialog extends StatefulWidget {
  const PlanExerciseSettingsDialog({
    super.key,
    required this.name,
    required this.initial,
    required this.onChanged,
    this.draft = false,
  });

  final String name;
  final PlanExercisesCompanion initial;
  final ValueChanged<PlanExercisesCompanion> onChanged;
  final bool draft;

  @override
  State<PlanExerciseSettingsDialog> createState() =>
      _PlanExerciseSettingsDialogState();
}

class _PlanExerciseSettingsDialogState
    extends State<PlanExerciseSettingsDialog> {
  late final _settings = context.read<Setting>();
  late final _max = TextEditingController(
    text:
        widget.initial.maxSets.value?.toString() ??
        _settings.maxSets.toString(),
  );
  late final _warmup = TextEditingController(
    text:
        widget.initial.warmupSets.value?.toString() ??
        (_settings.warmupSets ?? 0).toString(),
  );
  late var _timers = widget.initial.timers.present
      ? widget.initial.timers.value
      : true;

  @override
  void dispose() {
    _max.dispose();
    _warmup.dispose();
    super.dispose();
  }

  Widget _number(
    TextEditingController controller,
    String label,
    ValueChanged<String> onChanged,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: false),
    onTap: () => selectAll(controller),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog.adaptive(
    title: Text(widget.name),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: widget.draft ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _number(
            _warmup,
            context.l10n.warmupSets,
            (value) => widget.onChanged(
              PlanExercisesCompanion(
                warmupSets: Value(int.tryParse(value)),
                enabled: widget.draft
                    ? const Value(true)
                    : const Value.absent(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _number(_max, context.l10n.workingSetsMax, (value) {
            final parsed = int.tryParse(value);
            if (widget.draft && (parsed == null || parsed <= 0 || parsed > 20))
              return;
            widget.onChanged(
              PlanExercisesCompanion(
                maxSets: Value(parsed),
                enabled: widget.draft
                    ? const Value(true)
                    : const Value.absent(),
              ),
            );
          }),
          if (!widget.draft) const SizedBox(height: 16),
          ListTile(
            title: Text(context.l10n.restTimers),
            trailing: Switch(
              value: _timers,
              onChanged: (value) {
                setState(() => _timers = value);
                widget.onChanged(PlanExercisesCompanion(timers: Value(value)));
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () => Navigator.pop(context),
        label: Text(context.l10n.actionOk),
        icon: const Icon(Icons.check),
      ),
    ],
  );
}
