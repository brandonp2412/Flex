import 'dart:io';

import 'package:web/web.dart' as web;

Future<File> getDatabaseFile() async {
  throw UnsupportedError('Web databases do not have a filesystem path');
}

const _appearanceCacheKey = 'flex.appearance';

Future<String?> readAppearanceCache() async =>
    web.window.localStorage.getItem(_appearanceCacheKey);

Future<void> writeAppearanceCache(String value) async =>
    web.window.localStorage.setItem(_appearanceCacheKey, value);
