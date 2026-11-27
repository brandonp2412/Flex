import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class AccessCard extends StatelessWidget {
  const AccessCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: colors.onSurfaceVariant, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            Tooltip(
              message: context.l10n.allowed,
              child: Icon(Icons.check_circle, color: colors.primary),
            )
          else
            TextButton(
              onPressed: onRequest,
              child: Text(context.l10n.actionAllow),
            ),
        ],
      ),
    );
  }
}
