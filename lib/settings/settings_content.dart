import 'dart:io';

import 'package:flex/about_page.dart';
import 'package:flex/settings/settings_category_page.dart';
import 'package:flex/settings/settings_inputs.dart';
import 'package:flex/database/database.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/tab_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  late final SettingsInputs _inputs;

  @override
  void initState() {
    super.initState();
    _inputs = SettingsInputs(context.read<Setting>());
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Widget> filtered = [];
    final settings = context.watch<Setting>();
    final desktop = isDesktopLayout(context);
    if (_searchCtrl.text.isNotEmpty) {
      for (final category in SettingsCategory.values) {
        filtered.addAll(
          settingsItems(
            context,
            category,
            settings,
            _inputs,
            search: _searchCtrl.text,
          ),
        );
      }
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
                        for (final category in SettingsCategory.values)
                          ListTile(
                            leading: Icon(category.presentation(context).$1),
                            title: Text(category.presentation(context).$2),
                            subtitle: Text(category.presentation(context).$3),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            onTap: () => _openCategory(
                              category == SettingsCategory.tabs
                                  ? const TabSettings()
                                  : SettingsCategoryPage(category),
                            ),
                          ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(Widget page) {
    Navigator.of(context).push(FlexPageRoute(builder: (context) => page));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchCtrl.dispose();
    _inputs.dispose();
    super.dispose();
  }
}
