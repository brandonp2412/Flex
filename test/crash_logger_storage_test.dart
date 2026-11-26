import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex/crash_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unavailable log storage does not prevent startup', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'storage_unavailable');
    });
    try {
      final logger = await CrashLogger.install();
      expect(CrashLogger.instance, same(logger));
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    }
  });
}
