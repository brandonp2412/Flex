import 'package:flex/empty_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.error_outline_rounded,
    title: context.l10n.errorLabel,
    message: message ?? context.l10n.unexpectedError,
  );
}
