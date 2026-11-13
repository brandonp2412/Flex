import 'dart:io';

import 'package:flex/about_page.dart';
import 'package:flex/audio/safe_audio_player.dart';
import 'package:flex/database/database.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/appearance_settings.dart';
import 'package:flex/settings/data_settings.dart';
import 'package:flex/settings/format_settings.dart';
import 'package:flex/settings/plan_settings.dart';
import 'package:flex/settings/tab_settings.dart';
import 'package:flex/settings/timer_settings.dart';
import 'package:flex/settings/workout_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return const _SettingsContent();

    final parentNavigator = Navigator.of(context);

    return NavigatorPopHandler(
      onPopWithResult: (result) => _navigatorKey.currentState!.pop(result),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => FlexPageRoute(
          settings: settings,
          builder: (_) => _SettingsContent(
            onBack: parentNavigator.canPop()
                ? () => parentNavigator.maybePop()
                : null,
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent({this.onBack});

  final VoidCallback? onBack;

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  late final Setting _settings;
  late final TextEditingController _maxSets;
  late final TextEditingController _warmupSets;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;

  final SafeAudioPlayer _player = SafeAudioPlayer(enabled: !kIsWeb);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Widget> filtered = [];
    final settings = context.watch<Setting>();
    final desktop = isDesktopLayout(context);
    if (_searchCtrl.text.isNotEmpty) {
      filtered.addAll(
        getAppearanceSettings(context, _searchCtrl.text, settings),
      );
      filtered.addAll(getFormatSettings(context, _searchCtrl.text, settings));
      filtered.addAll(getWorkoutSettings(context, _searchCtrl.text, settings));
      if (_player.enabled)
        filtered.addAll(
          getTimerSettings(
            _searchCtrl.text,
            settings,
            _minutes,
            _seconds,
            _player,
            context,
          ),
        );
      filtered.addAll(getDataSettings(_searchCtrl.text, settings, context));
      filtered.addAll(
        getPlanSettings(
          context,
          _searchCtrl.text,
          settings,
          _maxSets,
          _warmupSets,
        ),
      );
    }

    if (filtered.isEmpty)
      filtered = [
        SizedBox(
          height: 360,
          child: AppEmptyState(
            icon: Icons.search_off_rounded,
            title: context.l10n.noSettingsFound,
            message: context.l10n.nothingMatchesSearch(_searchCtrl.text.trim()),
            actionLabel: context.l10n.clearSearch,
            actionIcon: Icons.close_rounded,
            onAction: () {
              _searchCtrl.clear();
              setState(() {});
            },
          ),
        ),
      ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: Text(context.l10n.navSettings),
        actions: [
          if (!kIsWeb && !Platform.isIOS && !Platform.isMacOS)
            IconButton(
              tooltip: context.l10n.aboutTitle,
              onPressed: () async {
                Navigator.of(
                  context,
                ).push(FlexPageRoute(builder: (context) => const AboutPage()));
              },
              icon: const Icon(Icons.info_outline_rounded),
            ),
        ],
      ),
      body: ResponsiveContent(
        maxWidth: 800,
        desktopPadding: EdgeInsets.zero,
        mobilePadding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _focusNode.requestFocus,
              child: Padding(
                padding: desktop
                    ? const EdgeInsets.fromLTRB(32, 12, 32, 0)
                    : const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SearchBar(
                  hintText: context.l10n.searchHint,
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  onTap: () => _focusNode.requestFocus(),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  onChanged: (_) => setState(() {}),
                  leading: SizedBox(
                    width: 24,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: _searchCtrl.text.isEmpty
                          ? context.l10n.searchHint
                          : context.l10n.clearSearch,
                      onPressed: () {
                        if (_searchCtrl.text.isEmpty) {
                          _focusNode.requestFocus();
                        } else {
                          _searchCtrl.clear();
                          setState(() {});
                        }
                      },
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Icon(
                          _searchCtrl.text.isEmpty
                              ? Icons.search
                              : Icons.close_rounded,
                          key: ValueKey(_searchCtrl.text.isEmpty),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ResponsiveSettingsList(
                children: _searchCtrl.text.isNotEmpty
                    ? filtered
                    : [
                        for (final category in _categories)
                          ListTile(
                            leading: Icon(category.$1),
                            title: Text(category.$2),
                            subtitle: Text(category.$3),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            onTap: () => _openCategory(category.$4),
                          ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(IconData, String, String, Widget)> get _categories => [
    (
      Icons.fitness_center_rounded,
      context.l10n.workouts,
      context.l10n.workoutsDescription,
      const WorkoutSettings(),
    ),
    (
      Icons.calendar_today_rounded,
      context.l10n.navPlans,
      context.l10n.plansSettingsDescription,
      const PlanSettings(),
    ),
    (
      Icons.timer_rounded,
      context.l10n.timers,
      context.l10n.timersDescription,
      const TimerSettings(),
    ),
    (
      Icons.color_lens_rounded,
      context.l10n.appearance,
      context.l10n.appearanceDescription,
      const AppearanceSettings(),
    ),
    (
      Icons.format_bold_rounded,
      context.l10n.formats,
      context.l10n.formatsDescription,
      const FormatSettings(),
    ),
    (
      Icons.tab_rounded,
      context.l10n.tabs,
      context.l10n.tabsDescription,
      const TabSettings(),
    ),
    (
      Icons.storage_rounded,
      context.l10n.dataManagement,
      context.l10n.dataManagementDescription,
      const DataSettings(),
    ),
  ];

  void _openCategory(Widget page) {
    Navigator.of(context).push(FlexPageRoute(builder: (context) => page));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchCtrl.dispose();
    _maxSets.dispose();
    _warmupSets.dispose();
    _minutes.dispose();
    _seconds.dispose();
    _player.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _settings = context.read<Setting>();
    _maxSets = TextEditingController(text: _settings.maxSets.toString());
    _warmupSets = TextEditingController(
      text: (_settings.warmupSets ?? 0).toString(),
    );
    _minutes = TextEditingController(
      text: Duration(
        milliseconds: _settings.timerDuration,
      ).inMinutes.toString(),
    );
    _seconds = TextEditingController(
      text: (Duration(milliseconds: _settings.timerDuration).inSeconds % 60)
          .toString(),
    );
  }
}
