import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/graph/graph_curve_settings.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/l10n/locale_preferences.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/theme_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<Widget> getAppearanceSettings(
  BuildContext context,
  String term,
  Setting settings,
) {
  final l10n = context.l10n;
  final normalizedTerm = term.trim().toLowerCase();
  bool matches(Iterable<String> values) =>
      values.join(' ').toLowerCase().contains(normalizedTerm);
  final localeTerms = [
    l10n.settingsLanguage,
    l10n.settingsLanguageDescription,
    l10n.languageSystemDefault,
    ...selectableLocales.map((locale) => localeDisplayName(l10n, locale)),
  ].join(' ').toLowerCase();
  final selectedLocale = validLocale(settings.localeOverride) ?? '';

  return [
    if (localeTerms.contains(normalizedTerm))
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              key: const Key('language-setting-dropdown'),
              initialValue: selectedLocale,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.settingsLanguage),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.languageSystemDefault),
                ),
                ...selectableLocales.map(
                  (locale) => DropdownMenuItem(
                    value: localeTag(locale),
                    child: Text(localeDisplayName(l10n, locale)),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                db.settings.update().write(
                  SettingsCompanion(
                    localeOverride: Value(value.isEmpty ? null : value),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    if (matches([
      l10n.themeLabel,
      l10n.themeSystem,
      l10n.themeDark,
      l10n.themeLight,
    ]))
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'ThemeMode.system',
              label: Text(l10n.themeSystem),
              icon: const Icon(Icons.brightness_auto),
            ),
            ButtonSegment(
              value: 'ThemeMode.dark',
              label: Text(l10n.themeDark),
              icon: const Icon(Icons.dark_mode),
            ),
            ButtonSegment(
              value: 'ThemeMode.light',
              label: Text(l10n.themeLight),
              icon: const Icon(Icons.light_mode),
            ),
          ],
          selected: {
            settings.themeMode == 'ThemeMode.amoled'
                ? 'ThemeMode.dark'
                : settings.themeMode,
          },
          onSelectionChanged: (selection) => db.settings.update().write(
            SettingsCompanion(themeMode: Value(selection.first)),
          ),
        ),
      ),
    if (matches([l10n.pureBlackAmoled, l10n.pureBlackAmoledDescription]))
      Tooltip(
        message: l10n.pureBlackAmoledDescription,
        child: ListTile(
          leading: settings.themeMode == 'ThemeMode.amoled'
              ? const Icon(Icons.contrast)
              : const Icon(Icons.contrast_outlined),
          title: Text(l10n.pureBlackAmoled, textAlign: TextAlign.start),
          onTap: () => db.settings.update().write(
            SettingsCompanion(
              themeMode: Value(
                settings.themeMode == 'ThemeMode.amoled'
                    ? 'ThemeMode.dark'
                    : 'ThemeMode.amoled',
              ),
            ),
          ),
          trailing: Switch(
            value: settings.themeMode == 'ThemeMode.amoled',
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(
                themeMode: Value(value ? 'ThemeMode.amoled' : 'ThemeMode.dark'),
              ),
            ),
          ),
        ),
      ),
    if (matches([l10n.systemColorScheme, l10n.systemColorSchemeDescription]))
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Tooltip(
          message: l10n.systemColorSchemeDescription,
          child: ListTile(
            title: Text(l10n.systemColorScheme, textAlign: TextAlign.start),
            leading: settings.systemColors
                ? const Icon(Icons.color_lens)
                : const Icon(Icons.color_lens_outlined),
            onTap: () => db.settings.update().write(
              SettingsCompanion(systemColors: Value(!settings.systemColors)),
            ),
            trailing: Switch(
              value: settings.systemColors,
              onChanged: (value) => db.settings.update().write(
                SettingsCompanion(systemColors: Value(value)),
              ),
            ),
          ),
        ),
      ),
    if (!settings.systemColors &&
        matches([
          l10n.appColor,
          l10n.customColor,
          l10n.hexColor,
          l10n.themeLabel,
          'color',
          'colour',
          'accent',
        ]))
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appColor, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _themeColors)
                  _colorSwatch(
                    context,
                    color: color,
                    selected: settings.seedColor == color.toARGB32(),
                    onTap: () => db.settings.update().write(
                      SettingsCompanion(seedColor: Value(color.toARGB32())),
                    ),
                  ),
                _colorSwatch(
                  context,
                  color:
                      _themeColors.any(
                        (color) => color.toARGB32() == settings.seedColor,
                      )
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Color(settings.seedColor),
                  selected: !_themeColors.any(
                    (color) => color.toARGB32() == settings.seedColor,
                  ),
                  custom: true,
                  onTap: () async {
                    final selected = await showThemeColorPicker(
                      context,
                      Color(settings.seedColor),
                    );
                    if (selected != null) {
                      await db.settings.update().write(
                        SettingsCompanion(
                          seedColor: Value(selected.toARGB32()),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    if (matches([l10n.showImages, l10n.showImagesDescription]))
      Tooltip(
        message: l10n.showImagesDescription,
        child: ListTile(
          title: Text(l10n.showImages, textAlign: TextAlign.start),
          leading: settings.showImages
              ? const Icon(Icons.image)
              : const Icon(Icons.image_outlined),
          onTap: () => db.settings.update().write(
            SettingsCompanion(showImages: Value(!settings.showImages)),
          ),
          trailing: Switch(
            value: settings.showImages,
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(showImages: Value(value)),
            ),
          ),
        ),
      ),
    if (matches([l10n.showGlobalProgress, l10n.showGlobalProgressDescription]))
      Tooltip(
        message: l10n.showGlobalProgressDescription,
        child: ListTile(
          title: Text(l10n.showGlobalProgress, textAlign: TextAlign.start),
          leading: settings.showGlobalProgress
              ? const Icon(Icons.public)
              : const Icon(Icons.public_outlined),
          onTap: () => db.settings.update().write(
            SettingsCompanion(
              showGlobalProgress: Value(!settings.showGlobalProgress),
            ),
          ),
          trailing: Switch(
            value: settings.showGlobalProgress,
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(showGlobalProgress: Value(value)),
            ),
          ),
        ),
      ),
    if (matches([l10n.peekGraph, l10n.peekGraphDescription]))
      Tooltip(
        message: l10n.peekGraphDescription,
        child: ListTile(
          title: Text(l10n.peekGraph, textAlign: TextAlign.start),
          leading: settings.peekGraph
              ? const Icon(Icons.visibility)
              : const Icon(Icons.visibility_outlined),
          onTap: () => db.settings.update().write(
            SettingsCompanion(peekGraph: Value(!settings.peekGraph)),
          ),
          trailing: Switch(
            value: settings.peekGraph,
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(peekGraph: Value(value)),
            ),
          ),
        ),
      ),
    if (matches([
      l10n.chartGridlines,
      l10n.chartShading,
      l10n.curveLineGraphs,
      l10n.curveLineGraphsDescription,
      l10n.curveSmoothness,
    ]))
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GraphCurveSettings(showPreview: true),
      ),
    if (matches([l10n.inputStyle, l10n.inputStyleDescription]))
      Tooltip(
        message: l10n.inputStyleDescription,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'underline',
                      label: Text(l10n.inputStyleLine, softWrap: false),
                    ),
                    ButtonSegment(
                      value: 'outlined',
                      label: Text(l10n.inputStyleOutlined, softWrap: false),
                    ),
                    ButtonSegment(
                      value: 'filled',
                      label: Text(l10n.inputStyleFilled, softWrap: false),
                    ),
                  ],
                  selected: {settings.inputStyle},
                  onSelectionChanged: (selection) => db.settings.update().write(
                    SettingsCompanion(inputStyle: Value(selection.first)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: l10n.inputStyle,
                decoration: InputDecoration(labelText: l10n.inputStyle),
                readOnly: true,
              ),
            ],
          ),
        ),
      ),
  ];
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(context.l10n.appearance)),
      body: ResponsiveSettingsList(
        children: getAppearanceSettings(context, '', settings),
      ),
    );
  }
}

const _themeColors = [
  Colors.deepPurple,
  Color(0xFF2B7A78),
  Color(0xFF1976D2),
  Color(0xFF388E3C),
  Color(0xFFD32F2F),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFF0097A7),
  Color(0xFF5D4037),
  Color(0xFF455A64),
];

Widget _colorSwatch(
  BuildContext context, {
  required Color color,
  required bool selected,
  required VoidCallback onTap,
  bool custom = false,
}) {
  final label = custom
      ? context.l10n.customColor
      : '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  return Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        key: Key(
          custom ? 'theme-color-custom' : 'theme-color-${color.toARGB32()}',
        ),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected || custom
              ? Icon(
                  custom ? Icons.colorize_rounded : Icons.check_rounded,
                  size: 19,
                  color: color.computeLuminance() > 0.45
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    ),
  );
}
