import 'package:flex/database/database.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Widget tabNavigator(
  BuildContext context, {
  required GlobalKey<NavigatorState> navigatorKey,
  required String tabName,
  required TabController? tabController,
  required WidgetBuilder builder,
  List<NavigatorObserver> observers = const [],
}) => NavigatorPopHandler(
  onPopWithResult: (_) {
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return;
    final index = context.read<Setting>().tabs.split(',').indexOf(tabName);
    if (tabController == null || tabController.index == index) navigator.pop();
  },
  child: Navigator(
    key: navigatorKey,
    observers: observers,
    onGenerateRoute: (settings) =>
        FlexPageRoute(settings: settings, builder: builder),
  ),
);
