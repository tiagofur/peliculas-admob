import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/cache/image_cache_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('ImageCacheManager should be initialized', () {
    final instance = ImageCacheManager.instance;
    expect(instance, isNotNull);
  });
}
