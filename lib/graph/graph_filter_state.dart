import 'package:flex/responsive.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/database/database.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class GraphFilterState<T extends StatefulWidget> extends State<T> {
  late String targetUnit;
  int get limit;
  void onLimitChanged(int value);
  DateTime? start;
  DateTime? end;

  List<DropdownMenuItem<String>> get optionsUnits;
  int get maxLimit => 100;
  bool? get optionsTimeAxis => null;
  void onTimeAxisUpdated(bool value) {}
  void setData();

  final _optionsVersion = ValueNotifier(0);

  void refreshOptions() {
    _optionsVersion.value++;
  }

  @override
  void dispose() {
    _optionsVersion.dispose();
    super.dispose();
  }

  void showOptions() {
    Widget options(BuildContext sheetContext) => ValueListenableBuilder(
      valueListenable: _optionsVersion,
      builder: (sheetContext, _, child) {
        void refresh(VoidCallback change, {bool reload = true}) {
          if (!mounted) return;
          setState(change);
          if (reload) setData();
          refreshOptions();
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
            child: SingleChildScrollView(
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
                  refresh(() => onLimitChanged(value));
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
          ),
        );
      },
    );
    if (isDesktopLayout(context)) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.options),
          content: SizedBox(width: 440, child: options(context)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.actionClose),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: options,
      );
    }
  }
}
