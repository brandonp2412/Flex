import 'package:flex/settings/setting_toggle.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/settings/plan_trailing_preview.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

List<Widget> getPlanSettings(
  BuildContext context,
  String term,
  Setting settings,
) {
  final l10n = context.l10n;
  bool matches(Iterable<String> values) => settingMatches(term, values);
  return [
    if (matches([l10n.warmupSets, l10n.warmupSetsDescription]))
      Padding(
        padding: settingsPadding,
        child: Tooltip(
          message: l10n.warmupSetsDescription,
          child: _SetCountField(
            key: const ValueKey('warmupSets'),
            value: settings.warmupSets ?? 0,
            label: l10n.warmupSets,
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(warmupSets: Value(int.tryParse(value) ?? 0)),
            ),
          ),
        ),
      ),
    if (matches([l10n.setsPerExerciseMax, l10n.setsPerExerciseDescription]))
      Padding(
        padding: settingsPadding,
        child: Tooltip(
          message: l10n.setsPerExerciseDescription,
          child: _SetCountField(
            key: const ValueKey('maxSets'),
            value: settings.maxSets,
            label: l10n.setsPerExerciseMax,
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed > 0 && parsed <= 20) {
                db.settings.update().write(
                  SettingsCompanion(maxSets: Value(parsed)),
                );
              }
            },
          ),
        ),
      ),
    if (matches([
      l10n.planTrailingDisplay,
      l10n.planTrailingDisplayDescription,
      l10n.countLabel,
      l10n.ratioLabel,
      l10n.reorder,
      l10n.none,
      ...PlanTrailing.values.map((value) => value.name),
      '%',
    ]))
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message: l10n.planTrailingDisplayDescription,
                child: Text(
                  l10n.planTrailingDisplay,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final current = PlanTrailing.values.byName(
                  settings.planTrailing.replaceFirst('PlanTrailing.', ''),
                );
                void save(PlanTrailing v) => db.settings.update().write(
                  SettingsCompanion(planTrailing: Value(v.toString())),
                );
                const progressOptions = {
                  PlanTrailing.count,
                  PlanTrailing.percent,
                  PlanTrailing.ratio,
                };
                const otherOptions = {PlanTrailing.reorder, PlanTrailing.none};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<PlanTrailing>(
                      emptySelectionAllowed: true,
                      selected: progressOptions.contains(current)
                          ? {current}
                          : {},
                      segments: [
                        ButtonSegment(
                          value: PlanTrailing.count,
                          label: Text(l10n.countLabel),
                          icon: const Icon(Icons.tag),
                        ),
                        const ButtonSegment(
                          value: PlanTrailing.percent,
                          label: Text('%'),
                          icon: Icon(Icons.percent),
                        ),
                        ButtonSegment(
                          value: PlanTrailing.ratio,
                          label: Text(l10n.ratioLabel),
                          icon: const Icon(Icons.format_list_numbered),
                        ),
                      ],
                      onSelectionChanged: (s) {
                        if (s.isNotEmpty) save(s.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<PlanTrailing>(
                      emptySelectionAllowed: true,
                      selected: otherOptions.contains(current) ? {current} : {},
                      segments: [
                        ButtonSegment(
                          value: PlanTrailing.reorder,
                          label: Text(l10n.reorder),
                          icon: const Icon(Icons.menu),
                        ),
                        ButtonSegment(
                          value: PlanTrailing.none,
                          label: Text(l10n.none),
                          icon: const Icon(Icons.block),
                        ),
                      ],
                      onSelectionChanged: (s) {
                        if (s.isNotEmpty) save(s.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    PlanTrailingPreview(trailing: current),
                  ],
                );
              },
            ),
          ],
        ),
      ),
  ];
}

class _SetCountField extends StatefulWidget {
  const _SetCountField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_SetCountField> createState() => _SetCountFieldState();
}

class _SetCountFieldState extends State<_SetCountField> {
  late final _controller = TextEditingController(text: widget.value.toString());
  final _focus = FocusNode();

  void _sync() {
    if (!_focus.hasFocus && int.tryParse(_controller.text) != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_sync);
  }

  @override
  void didUpdateWidget(_SetCountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _sync();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    decoration: InputDecoration(labelText: widget.label),
    keyboardType: const TextInputType.numberWithOptions(decimal: false),
    onTap: () => selectAll(_controller),
    onChanged: widget.onChanged,
  );

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }
}
