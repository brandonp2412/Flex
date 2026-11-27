import 'package:flex/settings/setting_toggle.dart';
import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flex/audio/safe_audio_player.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/progress_position_setting.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<Widget> getTimerSettings(
  String term,
  Setting settings,
  TextEditingController minCtrl,
  TextEditingController secCtrl,
  SafeAudioPlayer player,
  BuildContext context,
) {
  final l10n = context.l10n;
  final normalizedTerm = term.trim().toLowerCase();
  bool matches(Iterable<String> values) =>
      values.join(' ').toLowerCase().contains(normalizedTerm);
  return [
    if (matches([l10n.restTimers, l10n.restTimersDescription]))
      Tooltip(
        message: l10n.restTimersDescription,
        child: ListTile(
          title: Text(l10n.restTimers, textAlign: TextAlign.start),
          leading: settings.restTimers
              ? const Icon(Icons.timer)
              : const Icon(Icons.timer_outlined),
          onTap: () async {
            final newValue = !settings.restTimers;

            if (newValue &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android) {
              await androidChannel.invokeMethod('requestTimerPermissions', {
                'batteryOptimizationRequestUnavailable':
                    l10n.batteryOptimizationRequestUnavailable,
              });
            }

            db.settings.update().write(
              SettingsCompanion(restTimers: Value(newValue)),
            );
          },
          trailing: Switch(
            value: settings.restTimers,
            onChanged: (value) async {
              if (value &&
                  !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android) {
                await androidChannel.invokeMethod('requestTimerPermissions', {
                  'batteryOptimizationRequestUnavailable':
                      l10n.batteryOptimizationRequestUnavailable,
                });
              }

              db.settings.update().write(
                SettingsCompanion(restTimers: Value(value)),
              );
            },
          ),
        ),
      ),
    if (matches([l10n.vibrate, l10n.vibrateDescription]))
      Tooltip(
        message: l10n.vibrateDescription,
        child: ListTile(
          title: Text(l10n.vibrate, textAlign: TextAlign.start),
          leading: settings.vibrate
              ? const Icon(Icons.vibration)
              : const Icon(Icons.vibration_outlined),
          onTap: () async {
            final newValue = !settings.vibrate;
            await db.settings.update().write(
              SettingsCompanion(vibrate: Value(newValue)),
            );
            if (newValue &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android) {
              try {
                await androidChannel.invokeMethod('previewVibration');
              } catch (error, stackTrace) {
                talker.handle(error, stackTrace, 'Failed to preview vibration');
              }
            }
          },
          trailing: Switch(
            value: settings.vibrate,
            onChanged: (value) async {
              await db.settings.update().write(
                SettingsCompanion(vibrate: Value(value)),
              );
              if (value &&
                  !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android) {
                try {
                  await androidChannel.invokeMethod('previewVibration');
                } catch (error, stackTrace) {
                  talker.handle(
                    error,
                    stackTrace,
                    'Failed to preview vibration',
                  );
                }
              }
            },
          ),
        ),
      ),
    if (matches([l10n.enableSound, l10n.enableSoundDescription]))
      SettingToggle(
        title: Text(l10n.enableSound, textAlign: TextAlign.start),
        description: l10n.enableSoundDescription,
        value: settings.enableSound,
        icon: Icons.music_note,
        outlinedIcon: Icons.music_note_outlined,
        update: (value) => SettingsCompanion(enableSound: Value(value)),
      ),
    if (matches([l10n.keepRinging, l10n.keepRingingDescription]))
      SettingToggle(
        title: Text(l10n.keepRinging, textAlign: TextAlign.start),
        description: l10n.keepRingingDescription,
        value: settings.keepRinging,
        icon: Icons.notifications_active,
        outlinedIcon: Icons.notifications_none,
        update: (value) => SettingsCompanion(keepRinging: Value(value)),
      ),
    if (matches([l10n.keepScreenOn, l10n.keepScreenOnDescription]))
      Tooltip(
        message: l10n.keepScreenOnDescription,
        child: ListTile(
          title: Text(l10n.keepScreenOn, textAlign: TextAlign.start),
          leading: settings.keepScreenOn
              ? const Icon(Icons.light_mode)
              : const Icon(Icons.light_mode_outlined),
          onTap: () {
            final newValue = !settings.keepScreenOn;
            db.settings.update().write(
              SettingsCompanion(keepScreenOn: Value(newValue)),
            );
            context.read<TimerState>().setKeepScreenOn(newValue);
          },
          trailing: Switch(
            value: settings.keepScreenOn,
            onChanged: (value) {
              db.settings.update().write(
                SettingsCompanion(keepScreenOn: Value(value)),
              );
              context.read<TimerState>().setKeepScreenOn(value);
            },
          ),
        ),
      ),
    if (matches([
      l10n.restMinutes,
      l10n.secondsLabel,
      l10n.restDurationDescription,
      l10n.globalDefault,
    ]))
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Tooltip(
          message: l10n.restDurationDescription,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.public),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.globalDefault,
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(labelText: l10n.restMinutes),
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      onTap: () => selectAll(minCtrl),
                      onChanged: (value) => db.settings.update().write(
                        SettingsCompanion(
                          timerDuration: Value(
                            Duration(
                              minutes: int.tryParse(value) ?? 0,
                              seconds:
                                  Duration(
                                    milliseconds: settings.timerDuration,
                                  ).inSeconds %
                                  60,
                            ).inMilliseconds,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(labelText: l10n.secondsLabel),
                      controller: secCtrl,
                      keyboardType: TextInputType.number,
                      onTap: () => selectAll(secCtrl),
                      onChanged: (value) => db.settings.update().write(
                        SettingsCompanion(
                          timerDuration: Value(
                            Duration(
                              seconds: int.tryParse(value) ?? 0,
                              minutes: Duration(
                                milliseconds: settings.timerDuration,
                              ).inMinutes.floor(),
                            ).inMilliseconds,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    if (matches([
      l10n.progressBarPosition,
      l10n.progressBarPositionDescription,
      l10n.top,
      l10n.bottom,
      l10n.none,
    ]))
      ProgressPositionSetting(settings: settings),
    if (matches([
      l10n.alarmSound,
      l10n.alarmSoundDescription,
      if (settings.alarmSound.isNotEmpty) settings.alarmSound.split('/').last,
    ]))
      Tooltip(
        message: l10n.alarmSoundDescription,
        child: ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(
            settings.alarmSound.isEmpty
                ? l10n.alarmSound
                : settings.alarmSound.split('/').last,
          ),
          onTap: () async {
            final result = await FilePicker.pickFiles(type: FileType.audio);
            if (result.isEmpty || result.single.path == null) return;
            db.settings.update().write(
              SettingsCompanion(alarmSound: Value(result.single.path!)),
            );
            await player.playFile(result.single.path!);
          },
          trailing: settings.alarmSound.isEmpty
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
                  tooltip: l10n.actionDelete,
                  onPressed: () => db.settings.update().write(
                    const SettingsCompanion(alarmSound: Value('')),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
        ),
      ),
  ];
}

class TimerSettings extends StatefulWidget {
  const TimerSettings({super.key});

  @override
  State<TimerSettings> createState() => _TimerSettingsState();
}

class _TimerSettingsState extends State<TimerSettings> {
  late final Setting _settings = context.read<Setting>();
  late final _minCtrl = TextEditingController(
    text: (Duration(
      milliseconds: _settings.timerDuration,
    )).inMinutes.toString(),
  );
  late final _secCtrl = TextEditingController(
    text: ((Duration(milliseconds: _settings.timerDuration)).inSeconds % 60)
        .toString(),
  );

  final SafeAudioPlayer _player = SafeAudioPlayer(enabled: !kIsWeb);
  List<Exercise> _customExercises = [];
  final Map<String, TextEditingController> _minuteFields = {};
  final Map<String, TextEditingController> _secondFields = {};

  @override
  void initState() {
    super.initState();
    _loadExercisesWithCustomTimers();
  }

  Future<void> _loadExercisesWithCustomTimers() async {
    final exercises =
        await (db.exercises.select()
              ..where(
                (exercise) =>
                    exercise.defaultRestDurationMs.isNotNull() &
                    exercise.archived.equals(false),
              )
              ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]))
            .get();
    if (!mounted) return;

    setState(() {
      _customExercises = exercises;

      for (final result in exercises) {
        final exerciseName = result.name;
        final restMs = result.defaultRestDurationMs;
        if (restMs != null) {
          final duration = Duration(milliseconds: restMs);
          _minuteFields[exerciseName] = TextEditingController(
            text: duration.inMinutes.toString(),
          );
          _secondFields[exerciseName] = TextEditingController(
            text: (duration.inSeconds % 60).toString(),
          );
        }
      }
    });
  }

  Future<void> _updateExerciseRestTime(
    String exerciseName,
    int? minutes,
    int? seconds,
  ) async {
    Duration? duration;
    final mins = minutes ?? 0;
    final secs = seconds ?? 0;

    if (mins > 0 || secs > 0) {
      duration = Duration(minutes: mins, seconds: secs);
    }

    await (db.exercises.update()
          ..where((exercise) => exercise.name.equals(exerciseName)))
        .write(
          ExercisesCompanion(
            defaultRestDurationMs: Value(duration?.inMilliseconds),
          ),
        );

    if (!mounted) return;
    if (duration == null) {
      _minuteFields.remove(exerciseName)?.dispose();
      _secondFields.remove(exerciseName)?.dispose();
      setState(() {
        _customExercises.removeWhere((e) => e.name == exerciseName);
      });
    }
  }

  Future<void> _removeCustomTimer(String exerciseName) async {
    await (db.exercises.update()
          ..where((exercise) => exercise.name.equals(exerciseName)))
        .write(const ExercisesCompanion(defaultRestDurationMs: Value(null)));
    if (!mounted) return;

    _minuteFields.remove(exerciseName)?.dispose();
    _secondFields.remove(exerciseName)?.dispose();
    setState(() {
      _customExercises.removeWhere((e) => e.name == exerciseName);
    });
  }

  Widget _buildPerExerciseSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.fitness_center),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.perExerciseRestTimes,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.perExerciseRestTimesDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ..._customExercises.map((exercise) {
            final exerciseName = exercise.name;
            if (_minuteFields[exerciseName] == null ||
                _secondFields[exerciseName] == null)
              return const SizedBox();
            final minController = _minuteFields[exerciseName]!;
            final secController = _secondFields[exerciseName]!;

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exerciseName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeCustomTimer(exerciseName),
                          tooltip: context.l10n.removeCustomTimer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: context.l10n.minutesLabel,
                            ),
                            controller: minController,
                            keyboardType: TextInputType.number,
                            onTap: () => selectAll(minController),
                            onChanged: (value) {
                              final minutes = int.tryParse(value) ?? 0;
                              final seconds =
                                  int.tryParse(secController.text) ?? 0;
                              _updateExerciseRestTime(
                                exerciseName,
                                minutes,
                                seconds,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: context.l10n.secondsLabel,
                            ),
                            controller: secController,
                            keyboardType: TextInputType.number,
                            onTap: () => selectAll(secController),
                            onChanged: (value) {
                              final minutes =
                                  int.tryParse(minController.text) ?? 0;
                              final seconds = int.tryParse(value) ?? 0;
                              _updateExerciseRestTime(
                                exercise.name,
                                minutes,
                                seconds,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(context.l10n.timers)),
      body: ResponsiveSettingsList(
        children: _player.enabled
            ? [
                ...getTimerSettings(
                  '',
                  settings,
                  _minCtrl,
                  _secCtrl,
                  _player,
                  context,
                ),
                if (_customExercises.isNotEmpty) _buildPerExerciseSection(),
              ]
            : [
                ListTile(
                  title: Text(
                    context.l10n.timerSettings,
                    textAlign: TextAlign.start,
                  ),
                  subtitle: Text(
                    context.l10n.audioFeaturesUnavailable,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
      ),
    );
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();

    for (final controller in _minuteFields.values) {
      controller.dispose();
    }
    for (final controller in _secondFields.values) {
      controller.dispose();
    }

    _player.stop();
    _player.dispose();
    super.dispose();
  }
}
