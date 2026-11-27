import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flex/app.dart';
import 'package:flex/crash_logger.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/failed_migrations_page.dart';
import 'package:flex/logging.dart';
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
      } catch (error) {
        CrashLogger.instance?.record(
          error,
          StackTrace.current,
          context: 'database migration',
        );
        return runApp(FailedMigrationsPage(error: error));
      }

      talker.info('Loaded application settings');
      runApp(appProviders(setting));
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

Widget appProviders(Setting initialSettings) => ValueListenableBuilder<int>(
  valueListenable: dbVersion,
  builder: (context, version, child) => MultiProvider(
    key: ValueKey(version),
    providers: [
      StreamProvider<Setting>(
        initialData: initialSettings,
        create: (context) => db.watchSettings(),
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
