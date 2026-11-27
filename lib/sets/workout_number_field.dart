import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

FormFieldValidator<String> requiredNumberValidator(BuildContext context) =>
    (value) => value == null || value.isEmpty
    ? context.l10n.requiredField
    : parseDisplayNumber(context, value) == null
    ? context.l10n.invalidNumber
    : null;

FormFieldValidator<String> wholeNumberValidator(BuildContext context) =>
    (value) => value == null || value.isEmpty || int.tryParse(value) != null
    ? null
    : context.l10n.invalidNumber;

class WorkoutNumberField extends StatelessWidget {
  const WorkoutNumberField({
    super.key,
    required this.controller,
    required this.decoration,
    this.focusNode,
    this.integer = false,
    this.step,
    this.suffixIcon,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FocusNode? focusNode;
  final bool integer;
  final double? step;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  void _bump(BuildContext context, double delta) {
    final next = ((parseDisplayNumber(context, controller.text) ?? 0) + delta)
        .clamp(0, double.infinity)
        .toDouble();
    final text = formatEditableNumber(context, next);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final increment = step;
    return TextFormField(
      controller: controller,
      decoration: increment == null
          ? decoration
          : decoration.copyWith(
              suffixIcon: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  suffixIcon ?? const SizedBox(),
                  for (final direction in [-1, 1])
                    IconButton(
                      icon: Icon(direction < 0 ? Icons.remove : Icons.add),
                      onPressed: () => _bump(context, direction * increment),
                      onLongPress: () =>
                          _bump(context, direction * increment * 4),
                    ),
                ],
              ),
            ),
      focusNode: focusNode,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      onTap: () => selectAll(controller),
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textInputAction: textInputAction,
      validator:
          validator ??
          (increment != null
              ? null
              : integer
              ? wholeNumberValidator(context)
              : (value) =>
                    value == null ||
                        value.isEmpty ||
                        parseDisplayNumber(context, value) != null
                    ? null
                    : context.l10n.invalidNumber),
    );
  }
}
