import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbeacon/kbeacon.dart';

void main() {
  const MethodChannel channel = MethodChannel('kbeacon');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await Kbeacon.platformVersion, '42');
  });
}
