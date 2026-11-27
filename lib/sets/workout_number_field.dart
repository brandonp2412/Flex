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

FormFieldValidator<String> rawDecimalValidator(BuildContext context) =>
    (value) => value == null || value.isEmpty || double.tryParse(value) != null
    ? null
    : context.l10n.invalidNumber;

class WorkoutNumberField extends StatelessWidget {
  const WorkoutNumberField({
    super.key,
    required this.controller,
    required this.decoration,
    this.focusNode,
    this.integer = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FocusNode? focusNode;
  final bool integer;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: decoration,
    focusNode: focusNode,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    onTap: () => selectAll(controller),
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    textInputAction: textInputAction,
    validator:
        validator ??
        (integer
            ? wholeNumberValidator(context)
            : (value) =>
                  value == null ||
                      value.isEmpty ||
                      parseDisplayNumber(context, value) != null
                  ? null
                  : context.l10n.invalidNumber),
  );
}
