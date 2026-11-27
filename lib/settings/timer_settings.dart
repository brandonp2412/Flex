import 'package:flex/settings/setting_toggle.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flex/audio/safe_audio_player.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
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
  bool matches(Iterable<String> values) => settingMatches(term, values);
  return [
    ...matchingToggles(term, [
      SettingToggle(
        label: l10n.restTimers,
        description: l10n.restTimersDescription,
        value: settings.restTimers,
        icon: Icons.timer,
        outlinedIcon: Icons.timer_outlined,
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
      SettingToggle(
        label: l10n.vibrate,
        description: l10n.vibrateDescription,
        value: settings.vibrate,
        icon: Icons.vibration,
        outlinedIcon: Icons.vibration_outlined,
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
              talker.handle(error, stackTrace, 'Failed to preview vibration');
            }
          }
        },
      ),
      SettingToggle(
        label: l10n.enableSound,
        description: l10n.enableSoundDescription,
        value: settings.enableSound,
        icon: Icons.music_note,
        outlinedIcon: Icons.music_note_outlined,
        update: (value) => SettingsCompanion(enableSound: Value(value)),
      ),
      SettingToggle(
        label: l10n.keepRinging,
        description: l10n.keepRingingDescription,
        value: settings.keepRinging,
        icon: Icons.notifications_active,
        outlinedIcon: Icons.notifications_none,
        update: (value) => SettingsCompanion(keepRinging: Value(value)),
      ),
      SettingToggle(
        label: l10n.keepScreenOn,
        description: l10n.keepScreenOnDescription,
        value: settings.keepScreenOn,
        icon: Icons.light_mode,
        outlinedIcon: Icons.light_mode_outlined,
        onChanged: (value) {
          db.settings.update().write(
            SettingsCompanion(keepScreenOn: Value(value)),
          );
          context.read<TimerState>().setKeepScreenOn(value);
        },
      ),
    ]),
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
              timerDurationFields(
                context,
                minCtrl,
                secCtrl,
                minutesLabel: l10n.restMinutes,
                gap: 8,
                onMinutes: (minutes) => db.settings.update().write(
                  SettingsCompanion(
                    timerDuration: Value(
                      Duration(
                        minutes: minutes,
                        seconds:
                            Duration(
                              milliseconds: settings.timerDuration,
                            ).inSeconds %
                            60,
                      ).inMilliseconds,
                    ),
                  ),
                ),
                onSeconds: (seconds) => db.settings.update().write(
                  SettingsCompanion(
                    timerDuration: Value(
                      Duration(
                        minutes: Duration(
                          milliseconds: settings.timerDuration,
                        ).inMinutes,
                        seconds: seconds,
                      ).inMilliseconds,
                    ),
                  ),
                ),
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

Widget timerDurationFields(
  BuildContext context,
  TextEditingController minutes,
  TextEditingController seconds, {
  required String minutesLabel,
  required double gap,
  required ValueChanged<int> onMinutes,
  required ValueChanged<int> onSeconds,
}) {
  Widget field(
    TextEditingController controller,
    String label,
    ValueChanged<int> onChanged,
  ) => Expanded(
    child: TextField(
      decoration: InputDecoration(labelText: label),
      controller: controller,
      keyboardType: TextInputType.number,
      onTap: () => selectAll(controller),
      onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
    ),
  );
  return Row(
    children: [
      field(minutes, minutesLabel, onMinutes),
      SizedBox(width: gap),
      field(seconds, context.l10n.secondsLabel, onSeconds),
    ],
  );
}
