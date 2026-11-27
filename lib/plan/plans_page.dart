import 'package:flex/tab_navigator.dart';
import 'package:flex/database/database.dart';
import 'package:flex/plan/plans_navigator_observer.dart';
import 'package:flex/plan/plans_page_widget.dart';
import 'package:flex/plan/start_plan_page.dart';
import 'package:flutter/material.dart';

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
    return tabNavigator(
      context,
      navigatorKey: navKey,
      tabName: 'PlansPage',
      tabController: widget.tabController,
      observers: [_routeObserver],
      builder: (context) => PlansPageWidget(navKey: navKey),
    );
  }
}
