import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/core/cache/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CacheService service() => CacheService.instance;

  setUp(() {
    CacheService.instance.debugResetForTesting();
  });

  test('clear() preserves non-cache SharedPreferences keys', () async {
    SharedPreferences.setMockInitialValues({
      't1_plain': 'hello',
      't1_flag': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await service().set('t1_cached', 'v',
        expiration: const Duration(minutes: 5));

    await service().clear();

    expect(prefs.getString('t1_plain'), 'hello',
        reason: 'clear() must not wipe foreign keys');
    expect(prefs.getBool('t1_flag'), isTrue);
    expect(prefs.containsKey('t1_cached'), isFalse);
  });

  test('clearExpired() preserves undecodable foreign keys', () async {
    SharedPreferences.setMockInitialValues({
      't2_plain': 'not-json{{{',
      't2_queue': '{"op":"insert","table":"x"}',
    });
    final prefs = await SharedPreferences.getInstance();
    await service().set('t2_expired', 'v',
        expiration: const Duration(milliseconds: 1));
    await Future.delayed(const Duration(milliseconds: 5));

    await service().clearExpired();

    expect(prefs.getString('t2_plain'), 'not-json{{{',
        reason: 'undecodable keys are not ours to delete');
    expect(prefs.getString('t2_queue'), '{"op":"insert","table":"x"}');
    expect(prefs.containsKey('t2_expired'), isFalse);
  });

  test('get() on foreign key returns null without deleting', () async {
    SharedPreferences.setMockInitialValues({
      't3_plain': 'hello',
      't3_flag': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final value = await service().get<String>('t3_plain');

    expect(value, isNull);
    expect(prefs.getString('t3_plain'), 'hello',
        reason: 'reading a foreign key must not delete it');
    expect(await service().get<bool>('t3_flag'), isNull,
        reason: 'non-String keys must not throw');
    expect(prefs.getBool('t3_flag'), isTrue);
  });

  test('getCacheSize() ignores non-String keys without throwing', () async {
    SharedPreferences.setMockInitialValues({
      't4_flag': true,
      't4_count': 7,
    });
    await service().set('t4_cached', 'abcd');

    final size = await service().getCacheSize();

    expect(size, greaterThanOrEqualTo(0));
  });
}
