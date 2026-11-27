import 'package:flutter/material.dart';

class PlansNavigatorObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name;
  }
}
