import 'dart:async';

import 'package:flex/app_confirmation.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

mixin UnsavedChanges<T extends StatefulWidget> on State<T> {
  bool dirty = false;
  bool allowPop = false;
  bool _confirmingDiscard = false;

  void markDirty() {
    if (dirty) return;
    setState(() => dirty = true);
  }

  Widget guardUnsavedChanges({required Widget child}) => PopScope(
    canPop: allowPop || !dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop || allowPop || !dirty) return;
      unawaited(_confirmDiscard(result));
    },
    child: child,
  );

  Future<void> _confirmDiscard(Object? result) async {
    if (_confirmingDiscard) return;
    _confirmingDiscard = true;
    final discard = await showAppConfirmation(
      context,
      title: context.l10n.unsavedChanges,
      message: context.l10n.discardUnsavedChanges,
      actionLabel: context.l10n.actionDiscard,
      destructive: true,
    );
    _confirmingDiscard = false;
    if (!discard || !mounted) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }
}
