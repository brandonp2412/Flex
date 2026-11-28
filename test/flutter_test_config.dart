import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flex/logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  talker.configure(
    filter: TalkerFilter(disabledKeys: [TalkerKey.debug, TalkerKey.info]),
  );
  await testMain();
}
