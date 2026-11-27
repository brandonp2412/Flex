import 'package:flex/category_filter_field.dart';
import 'package:flex/sets/history_filters.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flex/database/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Filters extends StatefulWidget {
  final HistoryFilters filters;
  final VoidCallback onChanged;

  const Filters({super.key, required this.filters, required this.onChanged});

  @override
  createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  HistoryFilters get filters => widget.filters;
  int get filtersCount => filters.count;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: filtersCount,
      isLabelVisible: filtersCount > 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: IconButton(
        tooltip: context.l10n.filter,
        icon: const Icon(Icons.filter_list),
        onPressed: () => _showFilterDialog(context),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.filters),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategoryFilterField(
                  category: filters.category,
                  onChanged: (value) {
                    filters.category = value;
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                ),
                _rangeTile(
                  context,
                  Icons.repeat,
                  context.l10n.repsLabel,
                  context.l10n.repsFilter,
                  filters.repsGt,
                  filters.repsLt,
                ),
                _rangeTile(
                  context,
                  Icons.scale,
                  context.l10n.weightLabel,
                  context.l10n.weightFilter,
                  filters.weightGt,
                  filters.weightLt,
                ),
                _dateTile(
                  context,
                  Icons.calendar_today,
                  context.l10n.startDate,
                  filters.startDate,
                  (date) => filters.startDate = date,
                ),
                _dateTile(
                  context,
                  Icons.calendar_month,
                  context.l10n.endDate,
                  filters.endDate,
                  (date) => filters.endDate = date,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(context.l10n.actionClear),
            onPressed: () {
              filters.clear();
              widget.onChanged();
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: Text(context.l10n.actionClose),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _rangeTile(
    BuildContext dialogContext,
    IconData icon,
    String label,
    String title,
    TextEditingController greater,
    TextEditingController less,
  ) {
    final summary = [
      if (greater.text.isNotEmpty) '> ${greater.text}',
      if (less.text.isNotEmpty) '< ${less.text}',
    ].join(' ');
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: summary.isEmpty ? null : Text(summary),
      onTap: () {
        Navigator.pop(dialogContext);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (controller, label) in [
                    (greater, context.l10n.greaterThan),
                    (less, context.l10n.lessThan),
                  ])
                    TextField(
                      controller: controller,
                      onChanged: (_) => widget.onChanged(),
                      decoration: InputDecoration(labelText: label),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  greater.clear();
                  less.clear();
                  widget.onChanged();
                  Navigator.pop(context);
                },
                child: Text(context.l10n.actionClear),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.actionOk),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateTile(
    BuildContext dialogContext,
    IconData icon,
    String label,
    DateTime? date,
    ValueChanged<DateTime?> update,
  ) {
    final desktop = isDesktopLayout(dialogContext);
    void clear() {
      update(null);
      widget.onChanged();
      Navigator.pop(dialogContext);
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onLongPress: desktop ? null : clear,
      trailing: desktop && date != null
          ? IconButton(
              tooltip: dialogContext.l10n.actionClear,
              onPressed: clear,
              icon: const Icon(Icons.close),
            )
          : null,
      subtitle: Selector<Setting, String>(
        selector: (_, settings) => settings.shortDateFormat,
        builder: (context, format, child) => Text(
          date == null
              ? format
              : DateFormat(
                  format,
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(date),
        ),
      ),
      onTap: () async {
        Navigator.pop(dialogContext);
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) {
          update(picked.toLocal());
          widget.onChanged();
        }
      },
    );
  }
}
