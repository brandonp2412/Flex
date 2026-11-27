import 'package:flex/database/categories.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flex/database/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Filters extends StatefulWidget {
  final TextEditingController repsGtCtrl;
  final TextEditingController repsLtCtrl;
  final TextEditingController weightGtCtrl;
  final TextEditingController weightLtCtrl;
  final String? category;
  final Function(String?) setCategory;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?) setStart;
  final Function(DateTime?) setEnd;
  final Function setStream;

  const Filters({
    super.key,
    required this.repsGtCtrl,
    required this.repsLtCtrl,
    required this.weightGtCtrl,
    required this.weightLtCtrl,
    required this.setStart,
    required this.setEnd,
    required this.setStream,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.setCategory,
  });

  @override
  createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  int get filtersCount =>
      (widget.startDate != null ? 1 : 0) +
      (widget.endDate != null ? 1 : 0) +
      (widget.category != null ? 1 : 0) +
      (widget.weightGtCtrl.text.isNotEmpty ? 1 : 0) +
      (widget.weightLtCtrl.text.isNotEmpty ? 1 : 0) +
      (widget.repsLtCtrl.text.isNotEmpty ? 1 : 0) +
      (widget.repsGtCtrl.text.isNotEmpty ? 1 : 0);

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
          child: StreamBuilder(
            stream: getCategoriesStream(),
            builder: (context, snapshot) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField(
                      decoration: InputDecoration(
                        labelText: context.l10n.categoryLabel,
                      ),
                      initialValue: widget.category,
                      items: snapshot.data
                          ?.map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        widget.setCategory(value);
                        Navigator.pop(context);
                      },
                    ),
                    _rangeTile(
                      context,
                      Icons.repeat,
                      context.l10n.repsLabel,
                      context.l10n.repsFilter,
                      widget.repsGtCtrl,
                      widget.repsLtCtrl,
                    ),
                    _rangeTile(
                      context,
                      Icons.scale,
                      context.l10n.weightLabel,
                      context.l10n.weightFilter,
                      widget.weightGtCtrl,
                      widget.weightLtCtrl,
                    ),
                    _dateTile(
                      context,
                      Icons.calendar_today,
                      context.l10n.startDate,
                      widget.startDate,
                      widget.setStart,
                    ),
                    _dateTile(
                      context,
                      Icons.calendar_month,
                      context.l10n.endDate,
                      widget.endDate,
                      widget.setEnd,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(context.l10n.actionClear),
            onPressed: () async {
              widget.repsGtCtrl.text = '';
              widget.repsLtCtrl.text = '';
              widget.weightGtCtrl.text = '';
              widget.weightLtCtrl.text = '';
              widget.setStart(null);
              widget.setEnd(null);
              widget.setCategory(null);
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
                      onChanged: (_) => widget.setStream(),
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
                  widget.setStream();
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
    Function(DateTime?) update,
  ) {
    final desktop = isDesktopLayout(dialogContext);
    void clear() {
      update(null);
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
        if (picked != null && mounted) update(picked.toLocal());
      },
    );
  }
}
