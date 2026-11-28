import 'dart:convert';

import 'package:flex/database/database.dart';
import 'package:flex/logging.dart';
import 'package:flex/storage/app_storage.dart';

typedef AppAppearance = ({String themeMode, int seedColor, bool systemColors});

const defaultAppAppearance = (
  themeMode: 'ThemeMode.system',
  seedColor: 0xFF673AB7,
  systemColors: false,
);

AppAppearance appearanceFromSettings(Setting settings) => (
  themeMode: settings.themeMode,
  seedColor: settings.seedColor,
  systemColors: settings.systemColors,
);

Future<AppAppearance> loadAppAppearance() async {
  try {
    final stored = await readAppearanceCache();
    if (stored != null) {
      final values = jsonDecode(stored) as Map<String, dynamic>;
      return (
        themeMode: values['themeMode'] as String,
        seedColor: values['seedColor'] as int,
        systemColors: values['systemColors'] as bool,
      );
    }
  } catch (error, stack) {
    talker.handle(error, stack, 'Failed to read appearance cache');
  }
  return defaultAppAppearance;
}

Future<void> saveAppAppearance(AppAppearance appearance) async {
  try {
    await writeAppearanceCache(
      jsonEncode({
        'themeMode': appearance.themeMode,
        'seedColor': appearance.seedColor,
        'systemColors': appearance.systemColors,
      }),
    );
  } catch (error, stack) {
    talker.handle(error, stack, 'Failed to save appearance cache');
  }
}
