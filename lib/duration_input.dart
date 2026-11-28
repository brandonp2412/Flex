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
    FocusNode? minutesFocus,
    FocusNode? secondsFocus,
  }) => Row(
    children: [
      for (final (controller, label, focus) in [
        (minutes, minutesLabel, minutesFocus),
        (seconds, context.l10n.secondsLabel, secondsFocus),
      ]) ...[
        if (controller == seconds) SizedBox(width: gap),
        Expanded(
          child: TextField(
            decoration: InputDecoration(labelText: label),
            controller: controller,
            focusNode: focus,
            keyboardType: TextInputType.number,
            onTap: () => selectAll(controller),
            onChanged: (_) => onChanged(value),
          ),
        ),
      ],
    ],
  );
}

class DurationSettingsFields extends StatefulWidget {
  const DurationSettingsFields({
    super.key,
    required this.duration,
    required this.minutesLabel,
    required this.gap,
    required this.onChanged,
  });

  final Duration duration;
  final String minutesLabel;
  final double gap;
  final ValueChanged<Duration> onChanged;

  @override
  State<DurationSettingsFields> createState() => _DurationSettingsFieldsState();
}

class _DurationSettingsFieldsState extends State<DurationSettingsFields> {
  late final _input = DurationInput(initial: widget.duration);
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();

  void _sync() {
    if (!_minutesFocus.hasFocus &&
        !_secondsFocus.hasFocus &&
        _input.value.inSeconds != widget.duration.inSeconds) {
      _input.fill(widget.duration);
    }
  }

  @override
  void initState() {
    super.initState();
    _minutesFocus.addListener(_sync);
    _secondsFocus.addListener(_sync);
  }

  @override
  void didUpdateWidget(DurationSettingsFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) _sync();
  }

  @override
  Widget build(BuildContext context) => _input.settingsFields(
    context,
    minutesLabel: widget.minutesLabel,
    gap: widget.gap,
    onChanged: widget.onChanged,
    minutesFocus: _minutesFocus,
    secondsFocus: _secondsFocus,
  );

  @override
  void dispose() {
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    _input.dispose();
    super.dispose();
  }
}
