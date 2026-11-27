import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

class DurationInput {
  DurationInput({Duration? initial, String empty = ''})
    : minutes = TextEditingController(
        text: initial?.inMinutes.toString() ?? empty,
      ),
      seconds = TextEditingController(
        text: initial == null ? empty : (initial.inSeconds % 60).toString(),
      );

  final TextEditingController minutes, seconds;

  Duration get value => Duration(
    minutes: int.tryParse(minutes.text) ?? 0,
    seconds: int.tryParse(seconds.text) ?? 0,
  );
  int? get positiveMilliseconds =>
      value > Duration.zero ? value.inMilliseconds : null;
  bool get isEmpty => minutes.text.isEmpty && seconds.text.isEmpty;

  void fill(Duration value) {
    minutes.text = value.inMinutes.toString();
    seconds.text = (value.inSeconds % 60).toString();
  }

  void dispose() {
    minutes.dispose();
    seconds.dispose();
  }

  Widget settingsFields(
    BuildContext context, {
    required String minutesLabel,
    required double gap,
    required ValueChanged<Duration> onChanged,
  }) => Row(
    children: [
      for (final (controller, label) in [
        (minutes, minutesLabel),
        (seconds, context.l10n.secondsLabel),
      ]) ...[
        if (controller == seconds) SizedBox(width: gap),
        Expanded(
          child: TextField(
            decoration: InputDecoration(labelText: label),
            controller: controller,
            keyboardType: TextInputType.number,
            onTap: () => selectAll(controller),
            onChanged: (_) => onChanged(value),
          ),
        ),
      ],
    ],
  );
}
