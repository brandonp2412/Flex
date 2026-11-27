import 'package:flutter/material.dart';

class CompactSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CompactSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
