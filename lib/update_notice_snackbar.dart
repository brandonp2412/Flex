import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

SnackBar newVersionSnackBar(
  BuildContext context,
  String version,
  VoidCallback onChanges,
) => SnackBar(
  content: Text(context.l10n.newVersion(version)),
  behavior: SnackBarBehavior.floating,
  width: isDesktopLayout(context) ? 360 : null,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  action: SnackBarAction(label: context.l10n.changes, onPressed: onChanges),
  duration: const Duration(seconds: 4),
  persist: false,
);
