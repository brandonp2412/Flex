import 'package:flex/app_message.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabSettings extends StatelessWidget {
  const TabSettings({super.key});

  Future<void> _writeTabs(AppDatabase database, List<String> tabs) => database
      .settings
      .update()
      .write(SettingsCompanion(tabs: Value(tabs.join(','))));

  Future<void> _setTab(BuildContext context, String name, bool enabled) async {
    final database = db;
    await database.transaction(() async {
      final settings = await (database.settings.select()..limit(1)).getSingle();
      final tabs = settings.tabs.split(',');
      if (enabled == tabs.contains(name)) return;
      if (!enabled && tabs.length == 1) {
        if (context.mounted) showAppMessage(context.l10n.atLeastOneTab);
        return;
      }
      if (enabled) {
        tabs.add(name);
      } else {
        tabs.remove(name);
      }
      await _writeTabs(database, tabs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();
    final labels = <String, (IconData, String)>{
      'HistoryPage': (Icons.history, context.l10n.navHistory),
      'PlansPage': (Icons.calendar_today_outlined, context.l10n.navPlans),
      'GraphsPage': (Icons.insights_rounded, context.l10n.navGraphs),
      'TimerPage': (Icons.timer_outlined, context.l10n.navTimer),
      'SettingsPage': (Icons.settings_outlined, context.l10n.navSettings),
    };

    final enabled = settings.tabs.split(',');
    final tabs = [
      ...enabled,
      ...labels.keys.where((name) => !enabled.contains(name)),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(context.l10n.tabs)),
      body: ResponsiveSettingsList(
        children: [
          ListTile(
            leading: const Icon(Icons.swipe),
            title: Text(context.l10n.swipeBetweenTabs),
            trailing: Switch(
              value: settings.scrollableTabs,
              onChanged: (value) => db.settings.update().write(
                SettingsCompanion(scrollableTabs: Value(value)),
              ),
            ),
            onTap: () => db.settings.update().write(
              SettingsCompanion(
                scrollableTabs: Value(!settings.scrollableTabs),
              ),
            ),
          ),

          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            buildDefaultDragHandles: false,
            itemCount: tabs.length,
            onReorderItem: (oldIndex, newIndex) async {
              if (oldIndex >= enabled.length) return;
              final reordered = enabled.toList();
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex.clamp(0, reordered.length), moved);
              final database = db;
              await database.transaction(() async {
                final current = await (database.settings.select()..limit(1))
                    .getSingle();
                if (current.tabs == settings.tabs)
                  await _writeTabs(database, reordered);
              });
            },
            itemBuilder: (context, index) {
              final name = tabs[index];
              final isEnabled = index < enabled.length;
              final details = labels[name];
              if (details == null) {
                return ListTile(
                  key: Key(name),
                  title: Text(context.l10n.invalidTabSettings),
                );
              }
              return ListTile(
                key: Key(name),
                leading: Icon(details.$1),
                title: Text(details.$2),
                onTap: () => _setTab(context, name, !isEnabled),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isEnabled,
                      onChanged: (value) => _setTab(context, name, value),
                    ),
                    const SizedBox(width: 12),
                    if (isEnabled)
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
