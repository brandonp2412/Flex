import 'package:flex/settings/setting_toggle.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/graph/graph_curve_settings.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/l10n/locale_preferences.dart';
import 'package:flex/main.dart';
import 'package:flex/settings/theme_color_picker.dart';
import 'package:flutter/material.dart';

List<Widget> getAppearanceSettings(
  BuildContext context,
  String term,
  Setting settings,
) {
  final l10n = context.l10n;
  final normalizedTerm = term.trim().toLowerCase();
  bool matches(Iterable<String> values) => settingMatches(term, values);
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            ListTile(
              key: const Key('language-setting-dropdown'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsLanguage),
              subtitle: Text(
                selectedLocale.isEmpty
                    ? l10n.languageSystemDefault
                    : localeDisplayName(
                        l10n,
                        selectableLocales.firstWhere(
                          (locale) => localeTag(locale) == selectedLocale,
                        ),
                      ),
              ),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final value = await showDialog<String>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: Text(l10n.settingsLanguage),
                    children: [
                      for (final (tag, label) in [
                        ('', l10n.languageSystemDefault),
                        ...selectableLocales.map(
                          (locale) => (
                            localeTag(locale),
                            localeDisplayName(l10n, locale),
                          ),
                        ),
                      ])
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, tag),
                          child: Row(
                            children: [
                              Icon(
                                tag == selectedLocale
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(label)),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                if (value == null) return;
                await db.settings.update().write(
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
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
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
    ...matchingToggles(term, [
      SettingToggle(
        label: l10n.pureBlackAmoled,
        description: l10n.pureBlackAmoledDescription,
        value: settings.themeMode == 'ThemeMode.amoled',
        icon: Icons.contrast,
        outlinedIcon: Icons.contrast_outlined,
        update: (value) => SettingsCompanion(
          themeMode: Value(value ? 'ThemeMode.amoled' : 'ThemeMode.dark'),
        ),
      ),
    ]),
    if (matches([l10n.systemColorScheme, l10n.systemColorSchemeDescription]))
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: SettingToggle(
          label: l10n.systemColorScheme,
          description: l10n.systemColorSchemeDescription,
          value: settings.systemColors,
          icon: Icons.color_lens,
          outlinedIcon: Icons.color_lens_outlined,
          update: (value) => SettingsCompanion(systemColors: Value(value)),
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
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
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
    ...matchingToggles(term, [
      SettingToggle(
        label: l10n.showImages,
        description: l10n.showImagesDescription,
        value: settings.showImages,
        icon: Icons.image,
        outlinedIcon: Icons.image_outlined,
        update: (value) => SettingsCompanion(showImages: Value(value)),
      ),
      SettingToggle(
        label: l10n.showGlobalProgress,
        description: l10n.showGlobalProgressDescription,
        value: settings.showGlobalProgress,
        icon: Icons.public,
        outlinedIcon: Icons.public_outlined,
        update: (value) => SettingsCompanion(showGlobalProgress: Value(value)),
      ),
      SettingToggle(
        label: l10n.peekGraph,
        description: l10n.peekGraphDescription,
        value: settings.peekGraph,
        icon: Icons.visibility,
        outlinedIcon: Icons.visibility_outlined,
        update: (value) => SettingsCompanion(peekGraph: Value(value)),
      ),
    ]),
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
    if (matches([
      l10n.inputStyle,
      l10n.inputStyleDescription,
      l10n.inputStyleLine,
      l10n.inputStyleOutlined,
      l10n.inputStyleFilled,
      'underline',
      'outlined',
      'filled',
    ]))
      Tooltip(
        message: l10n.inputStyleDescription,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
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
