import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class GraphActionButtons extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onOptions;

  const GraphActionButtons({
    super.key,
    required this.onHistory,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        TextButton.icon(
          key: const Key('graph-history-button'),
          onPressed: onHistory,
          icon: const Icon(Icons.history),
          label: Text(context.l10n.navHistory),
        ),
        TextButton.icon(
          key: const Key('graph-options-button'),
          onPressed: onOptions,
          icon: const Icon(Icons.tune),
          label: Text(context.l10n.options),
        ),
      ],
    );
  }
}
