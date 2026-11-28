import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flex/app.dart';
import 'package:flex/crash_logger.dart';
import 'package:flex/database/database.dart';
import 'package:flex/logging.dart';
import 'package:flex/settings/app_appearance.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

export 'package:flex/unfocus_observer.dart';
export 'package:flex/keyboard_unfocus_wrapper.dart';
export 'package:flex/app.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();
Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      talker.info('Starting Flex');
      await CrashLogger.install();

      Setting setting;

      try {
        setting = await (db.settings.select()..limit(1)).getSingle();
      } catch (error, stack) {
        CrashLogger.instance?.record(
          error,
          stack,
          context: 'database migration',
        );
        final appearance = await loadAppAppearance();
        return runApp(App.recovery(error: error, appearance: appearance));
      }

      talker.info('Loaded application settings');
      var cachedAppearance = appearanceFromSettings(setting);
      var appearanceWrite = saveAppAppearance(cachedAppearance);
      await appearanceWrite;
      runApp(
        appProviders(
          setting,
          persistAppearance: (settings) async {
            final appearance = appearanceFromSettings(settings);
            if (appearance == cachedAppearance) return;
            cachedAppearance = appearance;
            appearanceWrite = appearanceWrite.then(
              (_) => saveAppAppearance(appearance),
            );
            await appearanceWrite;
          },
        ),
      );
    },
    (error, stack) =>
        CrashLogger.instance?.record(error, stack, context: 'zone'),
  );
}

AppDatabase db = AppDatabase.persistent();

/// Bumped whenever [db] is replaced with a new instance (e.g. after
/// importing a database), so widgets holding a `.watch()` stream tied to
/// the old instance know to rebuild it against the current one.
final ValueNotifier<int> dbVersion = ValueNotifier(0);

MethodChannel androidChannel = const MethodChannel(
  "com.presley.flexify/android",
);

Widget appProviders(
  Setting initialSettings, {
  Future<void> Function(Setting)? persistAppearance,
}) => ValueListenableBuilder<int>(
  valueListenable: dbVersion,
  builder: (context, version, child) => MultiProvider(
    key: ValueKey(version),
    providers: [
      StreamProvider<Setting>(
        initialData: initialSettings,
        create: (context) {
          final settings = db.watchSettings();
          if (persistAppearance == null) return settings;
          return settings.asyncMap((value) async {
            await persistAppearance(value);
            return value;
          });
        },
      ),
      ChangeNotifierProxyProvider<Setting, TimerState>(
        create: (context) => TimerState(),
        update: (context, settings, previous) =>
            previous!..setKeepScreenOn(settings.keepScreenOn),
      ),
    ],
    child: const App(),
  ),
);
