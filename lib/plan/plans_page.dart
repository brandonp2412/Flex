import 'package:flex/database/database.dart';
import 'package:flex/plan/plans_navigator_observer.dart';
import 'package:flex/plan/plans_page_widget.dart';
import 'package:flex/plan/start_plan_page.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

bool matchesPlanSearch(
  Plan plan,
  String search,
  Set<int> matchingPlanIds,
  String Function(String) localizeDay,
) {
  if (plan.title?.toLowerCase().contains(search) == true ||
      plan.days.toLowerCase().contains(search) ||
      matchingPlanIds.contains(plan.id)) {
    return true;
  }
  final localizedDays = plan.days
      .split(',')
      .where((day) => day.isNotEmpty)
      .map(localizeDay)
      .join(' ')
      .toLowerCase();
  return localizedDays.contains(search);
}

class PlansPage extends StatefulWidget {
  final TabController tabController;

  const PlansPage({super.key, required this.tabController});

  @override
  State<PlansPage> createState() => PlansPageState();
}

class PlansPageState extends State<PlansPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  final _routeObserver = PlansNavigatorObserver();

  @override
  bool get wantKeepAlive => true;

  /// Opens [plan] unless that workout is already the active Plans route.
  Future<void> openPlanFromNotification(Plan plan) async {
    final navigator = navKey.currentState;
    if (navigator == null) return;

    final routeName = 'start-plan:${plan.id}';
    if (_routeObserver.currentRouteName == routeName) return;

    await openStartPlan(navigator, plan);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NavigatorPopHandler(
      onPopWithResult: (result) {
        if (navKey.currentState!.canPop() == false) return;
        final settings = context.read<Setting>();
        final index = settings.tabs.split(',').indexOf('PlansPage');
        if (widget.tabController.index == index) navKey.currentState!.pop();
      },
      child: Navigator(
        key: navKey,
        observers: [_routeObserver],
        onGenerateRoute: (settings) => FlexPageRoute(
          builder: (context) => PlansPageWidget(navKey: navKey),
          settings: settings,
        ),
      ),
    );
  }
}
