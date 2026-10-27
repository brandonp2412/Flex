import 'dart:io';

import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class AppImageField extends StatelessWidget {
  const AppImageField({
    super.key,
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.image),
            label: Text(context.l10n.imageLabel),
          ),
          if (path != null)
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.removeImage),
            ),
        ],
      ),
      if (path != null) ...[
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          child: Image.file(
            File(path!),
            cacheWidth: 400,
            errorBuilder: (context, error, stackTrace) => TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.error_outline),
              label: Text(context.l10n.imageError),
            ),
          ),
        ),
      ],
    ],
  );
}
