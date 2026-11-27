import 'package:flex/database/database.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class GraphFilterState<T extends StatefulWidget> extends State<T> {
  late String targetUnit;
  late int limit;
  DateTime? start;
  DateTime? end;

  List<DropdownMenuItem<String>> get optionsUnits;
  int get maxLimit => 100;
  bool? get optionsTimeAxis => null;
  void onLimitUpdated() {}
  void onTimeAxisUpdated(bool value) {}
  void setData();

  void showOptions() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void refresh(VoidCallback change, {bool reload = true}) {
            if (!mounted) return;
            setState(change);
            if (reload) setData();
            if (sheetContext.mounted) setSheet(() {});
          }

          Future<void> pick(bool first) async {
            if (!mounted) return;
            final date = await showDatePicker(
              context: context,
              initialDate: first ? start : end,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null)
              refresh(() {
                if (first) {
                  start = date;
                } else {
                  end = date;
                }
              });
          }

          final units = optionsUnits;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: GraphOptionsControls(
                shortDateFormat: context.read<Setting>().shortDateFormat,
                unitValue: units.isEmpty ? null : targetUnit,
                unitItems: units,
                onUnitChanged: (value) => refresh(() => targetUnit = value),
                startDate: start,
                endDate: end,
                onSelectStart: () => pick(true),
                onClearStart: () => refresh(() => start = null),
                onSelectEnd: () => pick(false),
                onClearEnd: () => refresh(() => end = null),
                limit: limit,
                maxLimit: maxLimit,
                onLimitChanged: (value) {
                  refresh(() => limit = value);
                  if (mounted) onLimitUpdated();
                },
                timeBasedXAxis: optionsTimeAxis,
                onTimeAxisChange: optionsTimeAxis == null
                    ? null
                    : (value) => refresh(
                        () => onTimeAxisUpdated(value),
                        reload: false,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
