import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class KeyboardCloseObserver extends WidgetsBindingObserver {
  KeyboardCloseObserver(this.view, this.closed);

  final FlutterView view;
  final Completer<void> closed;

  @override
  void didChangeMetrics() {
    if (view.viewInsets.bottom == 0 && !closed.isCompleted) {
      closed.complete();
    }
  }
}
