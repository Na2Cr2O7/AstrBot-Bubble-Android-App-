import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_android/core/config/feature_flags.dart';
import 'package:astrbot_android/core/diagnostics/diagnostic_service.dart';
import 'package:astrbot_android/ui/controllers/openqq_controller.dart';

void main() {
  test('NapCat entry points stay disabled during OpenQQ migration', () {
    expect(kEnableNapCat, isFalse);
    expect(
      DiagnosticService.itemTitles,
      isNot(contains('NapCat 连接检查')),
    );
  });

  test('OpenQQ instance survives storage round-trip', () {
    final instance = OpenQQInstance()
      ..version = 'v0.3.0'
      ..qq = '1692860991'
      ..selfId = '1692860991'
      ..loggedIn = true
      ..webPort = OpenQQDefaults.webPort
      ..oneBotPort = OpenQQDefaults.oneBotPort;

    final restored = OpenQQInstance()..applyStorage(instance.toStorage());

    expect(restored.version, 'v0.3.0');
    expect(restored.selfId, '1692860991');
    expect(restored.loggedIn, isTrue);
    expect(restored.webPort, OpenQQDefaults.webPort);
    expect(restored.oneBotPort, OpenQQDefaults.oneBotPort);
  });
}
