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
      minutes = TextEditingController(
        text: Duration(
          milliseconds: settings.timerDuration,
        ).inMinutes.toString(),
      ),
      seconds = TextEditingController(
        text: (Duration(milliseconds: settings.timerDuration).inSeconds % 60)
            .toString(),
      );

  final TextEditingController maxSets, warmupSets, minutes, seconds;
  SafeAudioPlayer? _player;
  SafeAudioPlayer get player => _player ??= SafeAudioPlayer(enabled: !kIsWeb);

  void dispose() {
    for (final controller in [maxSets, warmupSets, minutes, seconds]) {
      controller.dispose();
    }
    _player?.dispose();
  }
}
