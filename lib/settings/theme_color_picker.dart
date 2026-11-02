import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

Future<Color?> showThemeColorPicker(BuildContext context, Color initialColor) =>
    showDialog<Color>(
      context: context,
      builder: (context) => ThemeColorPickerDialog(initialColor: initialColor),
    );

class ThemeColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ThemeColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ThemeColorPickerDialog> createState() => _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<ThemeColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;
  bool _validHex = true;

  static String _toHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _toHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _validHex = true;
      final hex = _toHex(value.toColor());
      _hexController.value = TextEditingValue(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
    });
  }

  void _setHex(String input) {
    final hex = input.trim().replaceFirst(RegExp(r'^#'), '');
    final isValid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex);
    setState(() {
      _validHex = isValid;
      if (isValid) {
        _hsv = HSVColor.fromColor(
          Color(0xFF000000 | int.parse(hex, radix: 16)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedColor = _hsv.toColor();
    return AlertDialog(
      title: Text(l10n.customColor),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      void update(Offset position) {
                        final saturation = (position.dx / constraints.maxWidth)
                            .clamp(0.0, 1.0);
                        final value = (1 - position.dy / constraints.maxHeight)
                            .clamp(0.0, 1.0);
                        _setHsv(
                          _hsv.withSaturation(saturation).withValue(value),
                        );
                      }

                      return GestureDetector(
                        onTapDown: (details) => update(details.localPosition),
                        onPanStart: (details) => update(details.localPosition),
                        onPanUpdate: (details) => update(details.localPosition),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: HSVColor.fromAHSV(
                                  1,
                                  _hsv.hue,
                                  1,
                                  1,
                                ).toColor(),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.transparent],
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black],
                                  ),
                                ),
                              ),
                              Positioned(
                                left:
                                    (_hsv.saturation * constraints.maxWidth - 9)
                                        .clamp(0.0, constraints.maxWidth - 18),
                                top:
                                    ((1 - _hsv.value) * constraints.maxHeight -
                                            9)
                                        .clamp(0.0, constraints.maxHeight - 18),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selectedColor,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        top: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.red,
                                Colors.yellow,
                                Colors.green,
                                Colors.cyan,
                                Colors.blue,
                                Colors.purple,
                                Colors.red,
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          trackHeight: 8,
                        ),
                        child: Slider(
                          key: const Key('theme-hue-slider'),
                          value: _hsv.hue,
                          min: 0,
                          max: 360,
                          label: l10n.customColor,
                          onChanged: (hue) => _setHsv(_hsv.withHue(hue)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('theme-hex-field'),
                        controller: _hexController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: l10n.hexColor,
                          errorText: _validHex ? null : l10n.hexColor,
                        ),
                        onChanged: _setHex,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('theme-color-save'),
          onPressed: _validHex
              ? () => Navigator.pop(context, _hsv.toColor())
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
