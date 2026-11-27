import 'package:flutter/material.dart';

class KeyboardUnfocusWrapper extends StatefulWidget {
  final Widget child;
  const KeyboardUnfocusWrapper({super.key, required this.child});

  @override
  State<KeyboardUnfocusWrapper> createState() => _KeyboardUnfocusWrapperState();
}

class _KeyboardUnfocusWrapperState extends State<KeyboardUnfocusWrapper>
    with WidgetsBindingObserver {
  double _lastInset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    if (_lastInset > 0.0 && bottomInset == 0.0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _lastInset = bottomInset;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: widget.child,
    );
  }
}
