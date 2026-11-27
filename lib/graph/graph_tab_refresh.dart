import 'package:flex/database/database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

mixin GraphTabRefresh<T extends StatefulWidget> on State<T> {
  TabController get graphTabController;
  Future<void> reloadGraph();

  late TabController _listenedController;

  @override
  void initState() {
    super.initState();
    _listenedController = graphTabController;
    _listenedController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listenedController == graphTabController) return;
    _listenedController.removeListener(_refresh);
    _listenedController = graphTabController;
    _listenedController.addListener(_refresh);
  }

  @override
  void dispose() {
    _listenedController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted || _listenedController.indexIsChanging) return;
    final index = context.read<Setting>().tabs.split(',').indexOf('GraphsPage');
    if (_listenedController.index == index) reloadGraph();
  }
}
