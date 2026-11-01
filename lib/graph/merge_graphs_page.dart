import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

/// Review and name an irreversible, transactional merge of exercise graphs.
class MergeGraphsPage extends StatefulWidget {
  const MergeGraphsPage({super.key, required this.summaries});

  final List<GraphExerciseSummary> summaries;

  @override
  State<MergeGraphsPage> createState() => _MergeGraphsPageState();
}

class _MergeGraphsPageState extends State<MergeGraphsPage> {
  final _customName = TextEditingController();
  int _selectedIndex = 0;
  bool _merging = false;
  String? _error;

  bool get _compatible {
    final items = widget.summaries;
    if (items.length < 2 || items.any((item) => item.bodyWeight)) {
      return false;
    }
    final first = items.first;
    return items.every(
      (item) =>
          item.cardio == first.cardio &&
          (!item.cardio || item.unit == first.unit),
    );
  }

  bool get _isNewName => _selectedIndex == widget.summaries.length;

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  Future<void> _merge() async {
    if (_merging || !_compatible) return;
    final chosen = _isNewName
        ? widget.summaries.first
        : widget.summaries[_selectedIndex];
    final name = _isNewName ? _customName.text.trim() : chosen.name;
    if (name.isEmpty) {
      setState(() => _error = context.l10n.mergeNameRequired);
      return;
    }

    setState(() {
      _merging = true;
      _error = null;
    });
    try {
      await mergeExerciseGraphs(
        db,
        exerciseIds: widget.summaries.map((item) => item.exerciseId!).toSet(),
        keepExerciseId: chosen.exerciseId!,
        name: name,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : context.l10n.mergeGraphsFailed;
        _merging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = widget.summaries;
    final chosenName = _isNewName
        ? context.l10n.mergeNewName
        : items[_selectedIndex].name;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(context.l10n.mergeGraphsTitle)),
      body: ResponsiveContent(
        maxWidth: 680,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.merge_type_rounded,
                    size: 38,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.mergeGraphsIntro(items.length),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.mergeGraphsExplanation,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.mergeGraphsWarning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.l10n.mergeNameLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey(_selectedIndex),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isNewName
                          ? Icons.edit_rounded
                          : Icons.check_circle_rounded,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chosenName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              ),
              child: Slider(
                key: const Key('merge-name-slider'),
                value: _selectedIndex.toDouble(),
                min: 0,
                max: items.length.toDouble(),
                divisions: items.length,
                label: chosenName,
                onChanged: _merging
                    ? null
                    : (value) => setState(() {
                        _selectedIndex = value.round();
                        _error = null;
                      }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items.first.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.mergeNewName,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (_isNewName) ...[
              const SizedBox(height: 20),
              TextField(
                key: const Key('merge-custom-name'),
                controller: _customName,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: context.l10n.mergeNewName,
                  hintText: context.l10n.mergeNameHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              Text(
                context.l10n.mergeNewNameSettings(items.first.name),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 26),
            Text(
              context.l10n.mergeGraphsIncluded,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  item.bodyWeight
                      ? Icons.monitor_weight_outlined
                      : item.cardio
                      ? Icons.directions_run_rounded
                      : Icons.fitness_center_rounded,
                ),
                title: Text(item.name),
                subtitle: Text(item.unit),
                trailing: const Icon(Icons.arrow_downward_rounded, size: 18),
              ),
            if (!_compatible) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.mergeGraphsIncompatible,
                style: TextStyle(color: colors.error),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const Key('confirm-merge-graphs'),
                onPressed: _compatible && !_merging ? _merge : null,
                icon: const Icon(Icons.merge_type_rounded),
                label: Text(context.l10n.mergeGraphs),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
