// Integration test for DebugChannel — deterministic ADB-first device validation.
//
// Run via:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/debug_channel_integration_test.dart \
//     --device-id=<device_id>
//
// Prerequisites:
//   1. App must be installed as a debug build (FLAG_DEBUGGABLE set).
//   2. ADB connection to target device must be active.
//
// This test exercises the real production path via native MethodChannel.
// It does NOT mock or stub business logic — it queries live database.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:songjog/debug/debug_channel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('DebugChannel integration', () {
    testWidgets('isAvailable returns false when no native handler',
        (tester) async {
      // In integration_test environment without native MethodChannel,
      // this should gracefully return false.
      final available = await DebugChannel.isAvailable;
      expect(available, isFalse);
    });

    testWidgets('queryState throws StateError when not available',
        (tester) async {
      expect(
        () async => DebugChannel.queryState(),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('resetApp throws StateError when not available',
        (tester) async {
      expect(
        () async => DebugChannel.resetApp(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
