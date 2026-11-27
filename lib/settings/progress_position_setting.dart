import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/native_timer_wrapper.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Displays the progress-bar-position picker and triggers the real
/// [TimerProgressIndicator] in the home page for 3 seconds as a preview
/// whenever the user changes the setting.
class ProgressPositionSetting extends StatefulWidget {
  final Setting settings;

  const ProgressPositionSetting({super.key, required this.settings});

  @override
  State<ProgressPositionSetting> createState() =>
      _ProgressPositionSettingState();
}

class _ProgressPositionSettingState extends State<ProgressPositionSetting> {
  Timer? _previewTimer;
  TimerState? _previewState;

  void _triggerPreview() {
    final timerState = context.read<TimerState>();
    if (timerState.timer.isRunning() &&
        timerState.timer.getRemaining() > Duration.zero) {
      return;
    }

    _previewTimer?.cancel();
    _previewState = timerState;
    const previewDuration = Duration(seconds: 3);
    timerState.updateTimer(
      NativeTimerWrapper(
        previewDuration,
        Duration.zero,
        DateTime.now(),
        NativeTimerState.running,
      ),
    );
    _previewTimer = Timer(previewDuration, () {
      if (!mounted) return;
      timerState.updateTimer(NativeTimerWrapper.emptyTimer());
      _previewState = null;
      _previewTimer = null;
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    if (_previewState != null) {
      _previewState!.updateTimer(NativeTimerWrapper.emptyTimer());
      _previewState = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.progressBarPositionDescription,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                context.l10n.progressBarPosition,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'top',
                    label: Text(context.l10n.top),
                    icon: const Icon(Icons.vertical_align_top),
                  ),
                  ButtonSegment(
                    value: 'bottom',
                    label: Text(context.l10n.bottom),
                    icon: const Icon(Icons.vertical_align_bottom),
                  ),
                  ButtonSegment(
                    value: 'none',
                    label: Text(context.l10n.none),
                    icon: const Icon(Icons.block),
                  ),
                ],
                selected: {widget.settings.progressPosition},
                onSelectionChanged: (selection) {
                  db.settings.update().write(
                    SettingsCompanion(progressPosition: Value(selection.first)),
                  );
                  if (selection.first != 'none') _triggerPreview();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
