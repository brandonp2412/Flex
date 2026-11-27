import 'package:flex/duration_input.dart';
import 'package:flex/audio/safe_audio_player.dart';
import 'package:flex/database/database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SettingsInputs {
  SettingsInputs(Setting settings)
    : maxSets = TextEditingController(text: settings.maxSets.toString()),
      warmupSets = TextEditingController(
        text: (settings.warmupSets ?? 0).toString(),
      ),
      rest = DurationInput(
        initial: Duration(milliseconds: settings.timerDuration),
      );

  final TextEditingController maxSets, warmupSets;
  final DurationInput rest;
  SafeAudioPlayer? _player;
  SafeAudioPlayer get player => _player ??= SafeAudioPlayer(enabled: !kIsWeb);

  void dispose() {
    for (final controller in [maxSets, warmupSets]) {
      controller.dispose();
    }
    rest.dispose();
    _player?.dispose();
  }
}
