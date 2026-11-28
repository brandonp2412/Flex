import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/failed_migrations_page.dart';
import 'package:flex/home_page.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/l10n/locale_preferences.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/no_animation_page_transitions_builder.dart';
import 'package:flex/settings/app_appearance.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

String? _backupLocale;

PageTransitionsTheme _pageTransitionsTheme() {
  final desktop =
      !kIsWeb &&
      {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);
  if (!desktop) return const PageTransitionsTheme();

  const noAnimation = NoAnimationPageTransitionsBuilder();
  return const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: noAnimation,
      TargetPlatform.fuchsia: noAnimation,
      TargetPlatform.iOS: noAnimation,
      TargetPlatform.linux: noAnimation,
      TargetPlatform.macOS: noAnimation,
      TargetPlatform.windows: noAnimation,
    },
  );
}

void _syncBackupLocalizations(AppLocalizations l10n) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (_backupLocale == l10n.localeName) return;
  _backupLocale = l10n.localeName;
  unawaited(
    androidChannel
        .invokeMethod<bool>('setBackupLocalizations', {
          'backupChannelName': l10n.backupChannelName,
          'backupChannelDescription': l10n.backupChannelDescription,
          'backupCompletedTitle': l10n.backupCompletedTitle,
          'backupFailurePathNotSet': l10n.backupFailurePathNotSet,
          'backupFailureDirectoryUnavailable':
              l10n.backupFailureDirectoryUnavailable,
          'backupFailureCreateFile': l10n.backupFailureCreateFile,
          'backupFailureAppFilesUnavailable':
              l10n.backupFailureAppFilesUnavailable,
          'backupFailureDatabaseMissing': l10n.backupFailureDatabaseMissing,
          'backupFailureOutputUnavailable': l10n.backupFailureOutputUnavailable,
          'backupFailureUnknown': l10n.backupFailureUnknown,
          'shareLabel': l10n.actionShare,
        })
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            _backupLocale = null;
            talker.handle(
              error,
              stackTrace,
              'Failed to sync backup localizations',
            );
          },
        ),
  );
}

class App extends StatelessWidget {
  static const _sliderTheme = SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
  );
  static const _popupMenuTheme = PopupMenuThemeData(
    menuPadding: EdgeInsets.zero,
  );

  static InputDecorationTheme _inputDecorationTheme(String inputStyle) {
    return switch (inputStyle) {
      'outlined' => const InputDecorationTheme(border: OutlineInputBorder()),
      'filled' => const InputDecorationTheme(filled: true),
      _ => const InputDecorationTheme(
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    };
  }

  const App({super.key}) : _recovery = null;

  const App.recovery({
    super.key,
    required Object error,
    required AppAppearance appearance,
  }) : _recovery = (error: error, appearance: appearance);

  final ({Object error, AppAppearance appearance})? _recovery;

  @override
  Widget build(BuildContext context) {
    final recovery = _recovery;
    final appearance =
        recovery?.appearance ??
        context.select<Setting, AppAppearance>(appearanceFromSettings);
    final amoledDark = appearance.themeMode == 'ThemeMode.amoled';
    final mode = switch (appearance.themeMode) {
      'ThemeMode.light' => ThemeMode.light,
      'ThemeMode.dark' || 'ThemeMode.amoled' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final inputStyle = recovery == null
        ? context.select((Setting settings) => settings.inputStyle)
        : 'line';
    final localeOverride = recovery == null
        ? context.select((Setting settings) => settings.localeOverride)
        : null;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final brightness = switch (mode) {
          ThemeMode.dark => Brightness.dark,
          ThemeMode.light => Brightness.light,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
        );

        final lightScheme = ColorScheme.fromSeed(
          seedColor: Color(appearance.seedColor),
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: Color(appearance.seedColor),
          brightness: Brightness.dark,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveSystemLocale,
          locale: localeOverrideFromIdentifier(localeOverride),
          navigatorObservers: [UnfocusObserver()],
          builder: (context, child) {
            if (recovery != null) return child ?? const SizedBox.shrink();
            _syncBackupLocalizations(context.l10n);
            context.read<TimerState>().setNotificationLocalizations(
              upTitle: context.l10n.timerUp,
              openLabel: context.l10n.openNotification,
              stopLabel: context.l10n.actionStop,
              addMinuteLabel: context.l10n.addOneMinuteNotification,
              restTitle: context.l10n.restTimer,
              timerChannel: context.l10n.timerChannelName,
              timerDesc: context.l10n.timerChannelDescription,
              doneChannel: context.l10n.timerFinishedChannelName,
              doneDesc: context.l10n.timerFinishedChannelDescription,
              doneTitle: context.l10n.timerFinished,
              alarmUnavailable: context.l10n.exactAlarmRequestUnavailable,
            );
            return KeyboardUnfocusWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: ThemeData(
            colorScheme: appearance.systemColors
                ? (lightDynamic ?? lightScheme)
                : lightScheme,
            fontFamily: 'Manrope',
            useMaterial3: true,
            sliderTheme: _sliderTheme,
            inputDecorationTheme: _inputDecorationTheme(inputStyle),
            popupMenuTheme: _popupMenuTheme,
            pageTransitionsTheme: _pageTransitionsTheme(),
          ),
          darkTheme: ThemeData(
            colorScheme:
                (appearance.systemColors
                        ? (darkDynamic ?? darkScheme)
                        : darkScheme)
                    .copyWith(surface: amoledDark ? Colors.black : null),
            fontFamily: 'Manrope',
            useMaterial3: true,
            sliderTheme: _sliderTheme,
            inputDecorationTheme: _inputDecorationTheme(inputStyle),
            popupMenuTheme: _popupMenuTheme,
            pageTransitionsTheme: _pageTransitionsTheme(),
          ),
          themeMode: mode,
          home: recovery == null
              ? const HomePage()
              : FailedMigrationsPage(error: recovery.error),
        );
      },
    );
  }
}
