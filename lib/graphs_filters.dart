import 'package:flex/category_filter_field.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

import 'constants.dart';

class GraphsFilters extends StatelessWidget {
  final String? category;
  final ValueChanged<String?> setCategory;

  final GraphSort sort;
  final ValueChanged<GraphSort> setSort;

  const GraphsFilters({
    super.key,
    required this.category,
    required this.setCategory,
    required this.sort,
    required this.setSort,
  });

  int get count =>
      (category != null ? 1 : 0) + (sort != GraphSort.dateDesc ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: PopupMenuButton(
        tooltip: context.l10n.filter,
        icon: const Icon(Icons.filter_list),
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<GraphSort>(
                  decoration: InputDecoration(labelText: context.l10n.sortBy),
                  initialValue: sort,
                  items: [
                    DropdownMenuItem(
                      value: GraphSort.dateDesc,
                      child: Text(context.l10n.dateNewest),
                    ),
                    DropdownMenuItem(
                      value: GraphSort.dateAsc,
                      child: Text(context.l10n.dateOldest),
                    ),
                    DropdownMenuItem(
                      value: GraphSort.name,
                      child: Text(context.l10n.nameLabel),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setSort(value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          PopupMenuItem(
            enabled: false,
            child: Column(
              children: [
                SizedBox(height: 8),
                CategoryFilterField(
                  category: category,
                  onChanged: (value) {
                    setCategory(value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: () {
              setCategory(null);
              setSort(GraphSort.dateDesc);
            },
            child: ListTile(
              leading: const Icon(Icons.clear),
              title: Text(context.l10n.actionClear),
            ),
          ),
        ],
      ),
    );
  }
}
