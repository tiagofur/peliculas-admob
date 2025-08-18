
import 'package:hive/hive.dart';

class PersistentSyncQueue {
  static const String _boxName = 'sync_queue';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> addItem(String itemId) async {
    await _box.put(itemId, itemId);
  }

  Future<void> removeItem(String itemId) async {
    await _box.delete(itemId);
  }

  List<String> getItems() {
    return _box.values.toList();
  }

  bool get isEmpty => _box.isEmpty;

  Future<void> clear() async {
    await _box.clear();
  }
}
