import 'package:flex/database/categories.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class CategoryFilterField extends StatelessWidget {
  const CategoryFilterField({
    super.key,
    required this.category,
    required this.onChanged,
  });

  final String? category;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<String>>(
    stream: getCategoriesStream(),
    builder: (context, snapshot) {
      final categories = {...?snapshot.data, ?category};
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: context.l10n.categoryLabel),
        initialValue: category,
        items: [
          for (final name in categories)
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: onChanged,
      );
    },
  );
}
