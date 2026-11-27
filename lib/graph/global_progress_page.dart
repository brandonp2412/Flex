import 'package:flex/database/categories.dart';
import 'package:flex/graph/graph_metric_chips.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flex/graph/graph_filter_state.dart';
import 'package:flex/graph/graph_period_picker.dart';
import 'package:flex/graph/strength_data.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flex/database/database.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GlobalProgressPage extends StatefulWidget {
  final TabController tabController;

  const GlobalProgressPage({super.key, required this.tabController});

  @override
  State<GlobalProgressPage> createState() => _GlobalProgressPageState();
}

class _GlobalProgressPageState extends GraphFilterState<GlobalProgressPage> {
  StrengthMetric metric = StrengthMetric.bestWeight;
  List<StrengthData> data = [];
  List<String?> categories = [];
  Map<StrengthDataLookupKey, StrengthData> _tooltipData = const {};
  Period period = Period.day;

  @override
  void initState() {
    super.initState();
    targetUnit = 'kg';
    limit = 100;
    setData();

    widget.tabController.addListener(tabListener);
  }

  void tabListener() {
    final settings = context.read<Setting>();
    final graphsIndex = settings.tabs.split(',').indexOf('GraphsPage');
    if (widget.tabController.indexIsChanging) return;
    if (widget.tabController.index != graphsIndex) return;
    setData();
  }

  @override
  void didUpdateWidget(GlobalProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController == widget.tabController) return;
    oldWidget.tabController.removeListener(tabListener);
    widget.tabController.addListener(tabListener);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(tabListener);
    super.dispose();
  }

  @override
  Future<void> setData() async {
    final request = beginDataRequest();
    final newData = await getGlobalData(
      target: targetUnit,
      metric: metric,
      period: period,
      start: start,
      end: end,
      limit: limit,
    );
    final newCategories = await getCategories();
    if (!isCurrentDataRequest(request)) return;
    setState(() {
      data = newData;
      categories = newCategories;
      _tooltipData = indexStrengthDataByCategoryAndDate(newData);
    });
  }

  List<Color> generateChartColors(BuildContext context, int count) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<double> hueValues = List.generate(
      count,
      (index) => (index * (360 / count)) % 360,
    );

    return hueValues.map((hue) {
      return HSLColor.fromAHSL(1.0, hue, 0.65, isDark ? 0.7 : 0.5).toColor();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();

    final chartColors = generateChartColors(context, categories.length);
    final allDates = data.map((d) => d.created).toSet().toList()..sort();
    final dateToXMap = <DateTime, int>{};
    for (var i = 0; i < allDates.length; i++) {
      dateToXMap[allDates[i]] = i;
    }

    final dataByCategory = groupStrengthDataByCategory(data);
    final chartSeries = <FlexLineChartSeries>[];
    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      final categoryData = dataByCategory[category] ?? const <StrengthData>[];
      chartSeries.add(
        FlexLineChartSeries(
          name: category ?? context.l10n.none,
          color: chartColors[index],
          points: [
            for (final row in categoryData)
              FlexLineChartPoint(
                dateToXMap[row.created]!.toDouble(),
                row.value,
                column: dateToXMap[row.created],
              ),
          ],
        ),
      );
    }

    final lineChart = FlexGroupedLineChart(
      series: chartSeries,
      xLabels: [
        for (final date in allDates)
          formatDisplayDate(context, date, settings.shortDateFormat),
      ],
      tooltipText: (seriesIndex, xIndex) =>
          tooltipText(seriesIndex, xIndex, allDates),
    );

    final desktop = isDesktopLayout(context);
    final theme = Theme.of(context);
    final metricOptions = strengthMetricOptions(
      context,
      showBodyWeight: settings.showBodyWeight,
    );
    final metricValue = metricOptions.any((option) => option.$1 == metric)
        ? metric
        : null;

    final metricSelector = DropdownButton<StrengthMetric>(
      value: metricValue,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
      items: metricOptions
          .map(
            (option) =>
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
          )
          .toList(),
      selectedItemBuilder: (context) => metricOptions
          .map(
            (option) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                option.$2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          metric = value!;
        });
        setData();
      },
    );
    final periodSelector = GraphPeriodPicker(
      selected: period,
      onChanged: (value) {
        setState(() {
          period = value;
        });
        setData();
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(context.l10n.globalProgress),
        actions: [
          IconButton(icon: const Icon(Icons.language), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            top: 16,
            right: 16,
            bottom: desktop ? 24.0 : bottomNavHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                Row(
                  children: [
                    Expanded(child: metricSelector),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: periodSelector),
                  ],
                )
              else ...[
                metricSelector,
                const SizedBox(height: 12),
                periodSelector,
              ],
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: data.isEmpty
                    ? AppEmptyState(
                        icon: Icons.show_chart_rounded,
                        title: context.l10n.noDataYet,
                        message: context.l10n.completeSetsForProgress,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(right: 32.0, top: 16.0),
                        child: lineChart,
                      ),
              ),
              if (data.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDisplayDate(
                        context,
                        data.first.created,
                        settings.shortDateFormat,
                      ),
                    ),
                    if (data.length > 2)
                      Text(
                        formatDisplayDate(
                          context,
                          data[data.length ~/ 2].created,
                          settings.shortDateFormat,
                        ),
                      ),
                    if (data.length > 1)
                      Text(
                        formatDisplayDate(
                          context,
                          data.last.created,
                          settings.shortDateFormat,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              GraphOptionsButton(onPressed: showOptions),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 16.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: chartColors
                        .asMap()
                        .entries
                        .map(
                          (entry) => SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioGroup<int>(
                                  groupValue: 1,
                                  onChanged: (value) {},
                                  child: Radio<int>(
                                    value: 1,
                                    fillColor: WidgetStateProperty.resolveWith(
                                      (states) => entry.value,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    categories[entry.key] ?? context.l10n.none,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  int get maxLimit => 200;

  @override
  List<DropdownMenuItem<String>> get optionsUnits =>
      context.read<Setting>().showUnits
      ? strengthUnitMenuItems(context.l10n)
      : const [];

  String tooltipText(int seriesIndex, int xIndex, List<DateTime> allDates) {
    if (seriesIndex < 0 ||
        seriesIndex >= categories.length ||
        xIndex < 0 ||
        xIndex >= allDates.length) {
      return '';
    }

    final category = categories[seriesIndex];
    final touchedDate = allDates[xIndex];
    final row = _tooltipData[(category: category, created: touchedDate)];
    if (row == null) return '';
    final formattedValue = formatDisplayNumber(
      context,
      row.value,
      minDigits: 2,
    );
    final displayUnit = displayMeasurementUnit(context.l10n, targetUnit);

    switch (metric) {
      case StrengthMetric.bestReps:
      case StrengthMetric.relativeStrength:
        return formattedValue;
      case StrengthMetric.volume:
      case StrengthMetric.oneRepMax:
        return "$formattedValue$displayUnit";
      case StrengthMetric.bestWeight:
        return "${formatDisplayNumber(context, row.reps, maxDigits: 0)} × $formattedValue$displayUnit";
    }
  }
}
