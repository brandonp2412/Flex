import 'package:flex/app_message.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/error_state.dart';
import 'package:flex/graph/graphs_page.dart';
import 'package:flex/home_compact_layout.dart';
import 'package:flex/home_wide_layout.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/plan/start_plan_page.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/history_page.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flex/settings/whats_new.dart';
import 'package:flex/timer/timer_page.dart';
import 'package:flex/timer/timer_progress_widgets.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/update_notice.dart';
import 'package:flex/update_notice_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

  static VoidCallback? registerNestedSettings(BuildContext context) => context
      .findAncestorStateOfType<_HomePageState>()
      ?.registerNestedSettings();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _controller;
  late final PageController _pages;
  late final TimerState _timerState;
  final GlobalKey<PlansPageState> _plansPageKey = GlobalKey<PlansPageState>();
  bool _desktopSettingsOpen = false;
  final Set<String> _nestedSettingsTabs = {};

  void Function()? registerNestedSettings() {
    final tab = context.read<Setting>().tabs.split(',')[_controller.index];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _nestedSettingsTabs.add(tab));
    });
    return () => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _nestedSettingsTabs.remove(tab));
    });
  }

  bool? _lastDesktopLayout;

  @override
  void initState() {
    super.initState();

    final setting = context.read<Setting>().tabs;
    final tabs = setting.split(',');
    _controller = TabController(length: tabs.length, vsync: this);
    _pages = PageController();
    _timerState = context.read<TimerState>();
    _timerState.addListener(_handleTimerNotificationTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleTimerNotificationTarget();
    });

    final info = PackageInfo.fromPlatform();
    info.then((pkg) async {
      final buildNumber = int.tryParse(pkg.buildNumber);
      if (buildNumber == null) return;
      final settings = await (db.settings.select()..limit(1)).getSingle();
      final oldBuild = settings.buildNumber;
      await db.settings.update().write(
        SettingsCompanion(buildNumber: Value(buildNumber)),
      );

      if (oldBuild == null ||
          buildNumber <= oldBuild ||
          !mounted ||
          !await updateNoticesEnabled() ||
          !await claimUpdateNotice()) {
        return;
      }

      if (mounted)
        messengerKey.currentState!.showSnackBar(
          newVersionSnackBar(
            context,
            pkg.version,
            () => Navigator.of(
              context,
            ).push(FlexPageRoute(builder: (context) => const WhatsNew())),
          ),
        );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final desktop = isDesktopLayout(context);
    if (desktop && _lastDesktopLayout != true) {
      final selectedIndex = _controller.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !isDesktopLayout(context) || !_pages.hasClients) return;
        _pages.jumpToPage(selectedIndex.clamp(0, _controller.length - 1));
      });
    }
    _lastDesktopLayout = desktop;
  }

  void _selectDesktopTab(int index) {
    if (_desktopSettingsOpen) {
      setState(() => _desktopSettingsOpen = false);
    }
    if (_controller.index != index) {
      _controller.index = index;
    }
    if (_pages.hasClients) {
      _pages.jumpToPage(index);
    }
  }

  void _openDesktopSettings() {
    final tabs = context.read<Setting>().tabs.split(',');
    final index = tabs.indexOf('SettingsPage');
    if (index >= 0) {
      _selectDesktopTab(index);
    } else if (!_desktopSettingsOpen) {
      setState(() => _desktopSettingsOpen = true);
    }
  }

  Future<void> _handleTimerNotificationTarget() async {
    if (!mounted) return;
    final target = _timerState.consumeNotificationTarget();
    if (target == null) return;

    final navigator = Navigator.of(context);
    final tabs = context.read<Setting>().tabs.split(',');
    if (target == 'history' || target == 'timer') {
      final tab = target == 'history' ? 'HistoryPage' : 'TimerPage';
      final index = tabs.indexOf(tab);
      if (index >= 0 && index < _controller.length) {
        if (isDesktopLayout(context)) {
          _selectDesktopTab(index);
        } else {
          _controller.animateTo(index);
        }
      } else if (target == 'timer') {
        await navigator.push(
          FlexPageRoute(builder: (context) => const TimerPage()),
        );
      }
      return;
    }

    if (!target.startsWith('plan:')) return;
    final planId = int.tryParse(target.substring('plan:'.length));
    if (planId == null) return;
    final plan =
        await (db.plans.select()..where((row) => row.id.equals(planId)))
            .getSingleOrNull();
    if (plan == null || !mounted) return;

    final plansIndex = tabs.indexOf('PlansPage');
    if (plansIndex >= 0 && plansIndex < _controller.length) {
      if (isDesktopLayout(context)) {
        _selectDesktopTab(plansIndex);
      } else {
        _controller.animateTo(plansIndex);
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final plansPage = _plansPageKey.currentState;
      if (plansPage != null) {
        await plansPage.openPlanFromNotification(plan);
        return;
      }
    }

    await openStartPlan(navigator, plan);
  }

  @override
  void dispose() {
    _timerState.removeListener(_handleTimerNotificationTarget);
    _controller.dispose();
    _pages.dispose();
    super.dispose();
  }

  void hideTab(BuildContext context, String tab) async {
    final state = context.read<Setting>();
    final tabs = state.tabs.split(',');

    if (tabs.length == 1) {
      showAppMessage(context.l10n.cannotHideAllTabs);
      return;
    }

    final label = BottomNav.labelForTab(context, tab);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(BottomNav.iconForTab(tab)),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.removeTabQuestion(label),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.restoreTabFromSettings,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.actionCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.actionRemove),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    tabs.remove(tab);
    await db.settings.update().write(
      SettingsCompanion(tabs: Value(tabs.join(','))),
    );
    if (context.mounted) showAppMessage(context.l10n.removedTab(label));
  }

  @override
  Widget build(BuildContext context) {
    final tabSettings = context.select<Setting, String>(
      (settings) => settings.tabs,
    );
    final tabs = tabSettings.split(',');
    final scrollableTabs = context.select<Setting, bool>(
      (settings) => settings.scrollableTabs,
    );

    if (tabs.length != _controller.length) {
      final index = _controller.index.clamp(0, tabs.length - 1);
      _controller.dispose();
      _controller = TabController(
        length: tabs.length,
        initialIndex: index,
        vsync: this,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) {
          _pages.jumpToPage(index);
        }
      });
    }

    final desktop = isDesktopLayout(context);
    final pages = tabs.map((tab) {
      if (tab == 'HistoryPage') {
        return HistoryPage(tabController: _controller);
      } else if (tab == 'PlansPage') {
        return PlansPage(key: _plansPageKey, tabController: _controller);
      } else if (tab == 'GraphsPage') {
        return GraphsPage(tabController: _controller);
      } else if (tab == 'TimerPage') {
        return TimerPage(tabController: _controller);
      } else if (tab == 'SettingsPage') {
        return const SettingsPage();
      } else {
        return AppErrorState(message: context.l10n.tabContentError);
      }
    }).toList();

    final progress = Consumer<Setting>(
      builder: (context, settings, child) => Positioned(
        top: settings.progressPosition == 'top' ? 8 : null,
        bottom: switch (settings.progressPosition) {
          'bottom' when desktop => 12,
          'bottom' => 0,
          _ => null,
        },
        left: desktop ? 24 : 48,
        right: desktop ? 24 : 48,
        child: settings.progressPosition != 'none'
            ? const TimerProgressIndicator()
            : const SizedBox(),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      extendBody: !desktop,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: desktop
            ? HomeWideLayout(
                tabs: tabs,
                tabController: _controller,
                pageController: _pages,
                pages: pages,
                onSelectTab: _selectDesktopTab,
                onHideTab: hideTab,
                onOpenSettings: _openDesktopSettings,
                settingsOpen: _desktopSettingsOpen,
                nestedSettingsTabs: _nestedSettingsTabs,
                progress: progress,
              )
            : HomeCompactLayout(
                tabs: tabs,
                controller: _controller,
                pages: pages,
                scrollable: scrollableTabs,
                onHideTab: hideTab,
                progress: progress,
              ),
      ),
    );
  }
}
