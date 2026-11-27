import 'package:flex/database/database.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/timer/timer_page_widget.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TimerPage extends StatefulWidget {
  final int? total;
  final int? progress;
  final TabController? tabController;

  const TimerPage({super.key, this.total, this.progress, this.tabController});

  @override
  createState() => TimerPageState();
}

class TimerPageState extends State<TimerPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final timerState = context.watch<TimerState>();

    return NavigatorPopHandler(
      onPopWithResult: (result) {
        if (_navKey.currentState!.canPop() == false) return;
        final settings = context.read<Setting>();
        final index = settings.tabs.split(',').indexOf('TimerPage');
        final tabController = widget.tabController;
        if (tabController == null || tabController.index == index) {
          _navKey.currentState!.pop();
        }
      },
      child: Navigator(
        key: _navKey,
        onGenerateRoute: (settings) => FlexPageRoute(
          builder: (context) => TimerPageWidget(
            timerState: timerState,
            total: widget.total,
            progress: widget.progress,
          ),
          settings: settings,
        ),
      ),
    );
  }
}
