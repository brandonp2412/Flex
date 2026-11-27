import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class GraphOptionsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GraphOptionsButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        key: const Key('graph-options-button'),
        onPressed: onPressed,
        icon: const Icon(Icons.tune),
        label: Text(context.l10n.options),
      ),
    );
  }
}
