import 'package:flex/tab_navigator.dart';
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

    return tabNavigator(
      context,
      navigatorKey: _navKey,
      tabName: 'TimerPage',
      tabController: widget.tabController,
      builder: (context) => TimerPageWidget(
        timerState: timerState,
        total: widget.total,
        progress: widget.progress,
      ),
    );
  }
}
