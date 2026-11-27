import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/settings_content.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return const SettingsContent();

    final parentNavigator = Navigator.of(context);

    return NavigatorPopHandler(
      onPopWithResult: (result) => _navigatorKey.currentState!.pop(result),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => FlexPageRoute(
          settings: settings,
          builder: (_) => SettingsContent(
            onBack: parentNavigator.canPop()
                ? () => parentNavigator.maybePop()
                : null,
          ),
        ),
      ),
    );
  }
}
