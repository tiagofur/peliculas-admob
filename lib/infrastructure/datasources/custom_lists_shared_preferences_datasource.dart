import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/custom_list.dart';

abstract class CustomListsDatasource {
  Future<List<CustomList>> getCustomLists();
  Future<void> saveCustomLists(List<CustomList> lists);
  Future<void> addCustomList(CustomList list);
  Future<void> updateCustomList(CustomList list);
  Future<void> deleteCustomList(String listId);
  Future<void> clearAllCustomLists();
  
  // Métodos para listas predeterminadas
  Future<List<CustomList>> getDefaultLists();
  Future<void> saveDefaultLists(List<CustomList> lists);
}

class CustomListsSharedPreferencesDatasource extends CustomListsDatasource {
  static const String _customListsKey = 'custom_lists';
  static const String _defaultListsKey = 'default_lists';

  @override
  Future<List<CustomList>> getCustomLists() async {
    final prefs = await SharedPreferences.getInstance();
    final customListsJson = prefs.getStringList(_customListsKey) ?? [];
    
    return customListsJson
        .map((listJson) => _customListFromJson(jsonDecode(listJson)))
        .toList();
  }

  @override
  Future<void> saveCustomLists(List<CustomList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final customListsJson = lists
        .map((list) => jsonEncode(_customListToJson(list)))
        .toList();
    
    await prefs.setStringList(_customListsKey, customListsJson);
  }

  @override
  Future<void> addCustomList(CustomList list) async {
    final currentLists = await getCustomLists();
    currentLists.add(list);
    await saveCustomLists(currentLists);
  }

  @override
  Future<void> updateCustomList(CustomList list) async {
    final currentLists = await getCustomLists();
    final index = currentLists.indexWhere((l) => l.id == list.id);
    
    if (index != -1) {
      currentLists[index] = list;
      await saveCustomLists(currentLists);
    }
  }

  @override
  Future<void> deleteCustomList(String listId) async {
    final currentLists = await getCustomLists();
    currentLists.removeWhere((list) => list.id == listId);
    await saveCustomLists(currentLists);
  }

  @override
  Future<void> clearAllCustomLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customListsKey);
  }

  @override
  Future<List<CustomList>> getDefaultLists() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultListsJson = prefs.getStringList(_defaultListsKey) ?? [];
    
    return defaultListsJson
        .map((listJson) => _customListFromJson(jsonDecode(listJson)))
        .toList();
  }

  @override
  Future<void> saveDefaultLists(List<CustomList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultListsJson = lists
        .map((list) => jsonEncode(_customListToJson(list)))
        .toList();
    
    await prefs.setStringList(_defaultListsKey, defaultListsJson);
  }

  // Métodos de serialización
  Map<String, dynamic> _customListToJson(CustomList list) {
    return {
      'id': list.id,
      'name': list.name,
      'description': list.description,
      'emoji': list.emoji,
      'movieIds': list.movieIds,
      'createdAt': list.createdAt.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
      'isDefault': list.isDefault,
      'color': list.color,
    };
  }

  CustomList _customListFromJson(Map<String, dynamic> json) {
    return CustomList(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String,
      emoji: json['emoji'] as String,
      movieIds: List<int>.from(json['movieIds'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
      color: json['color'] as String? ?? 'blue',
    );
  }
}